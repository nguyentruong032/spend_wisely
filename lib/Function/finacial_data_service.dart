import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class FinancialDataService {
  static Future<Map<String, dynamic>> getUserFinancialSummary(
    String uid, {
    int yearsBack = 1,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year - yearsBack, now.month, now.day);
    final startTimestamp = startDate.millisecondsSinceEpoch;

    // ── BƯỚC 1: Lấy toàn bộ categories để tạo mapping id → name ───────
    final categoriesRef = FirebaseDatabase.instance.ref('categories');
    final categoriesSnapshot = await categoriesRef.get();

    final Map<String, String> categoryMap = {};

    if (categoriesSnapshot.exists && categoriesSnapshot.value != null) {
      final categoriesData = categoriesSnapshot.value as Map<dynamic, dynamic>;
      categoriesData.forEach((key, value) {
        final cat = value as Map<dynamic, dynamic>;
        final name = cat['name'] as String? ?? 'Không xác định';
        categoryMap[key.toString()] = name;
      });
    }

    // ── BƯỚC 2: Lấy transactions ──────────────────────────────────────
    final ref = FirebaseDatabase.instance.ref('transactions');
    final snapshot = await ref.orderByChild('user_id').equalTo(uid).once();

    if (!snapshot.snapshot.exists) {
      return {'summaryText': 'Chưa có giao dịch nào trong $yearsBack năm qua.'};
    }

    double totalIncome = 0;
    double totalExpense = 0;
    final categoryBreakdown = <String, double>{}; // key là TÊN, không phải id
    final monthlyNet = <String, double>{};
    final recentTx = <Map<String, dynamic>>[];

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (data != null) {
      data.forEach((key, value) {
        final tx = value as Map<dynamic, dynamic>;
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final dateMs = tx['date'] as int? ?? 0;
        final type = tx['type'] as String?;
        final categoryId = tx['category_id'] as String? ?? 'unknown';
        final note = tx['note'] as String? ?? '';

        if (dateMs < startTimestamp) return;

        // Lấy tên category từ map (fallback nếu không tìm thấy)
        final categoryName = categoryMap[categoryId] ?? categoryId;

        if (type == 'income') {
          totalIncome += amount;
        } else if (type == 'expense') {
          totalExpense += amount;
        }

        // Phân loại theo TÊN
        if (type == 'expense') {
          categoryBreakdown[categoryName] =
              (categoryBreakdown[categoryName] ?? 0) + amount;
        }

        // Monthly net
        final monthKey = DateTime.fromMillisecondsSinceEpoch(
          dateMs,
        ).toString().substring(0, 7); // YYYY-MM
        monthlyNet[monthKey] =
            (monthlyNet[monthKey] ?? 0) + (type == 'income' ? amount : -amount);

        // Recent transactions (dùng tên thay vì id)
        if (recentTx.length < 15) {
          recentTx.add({
            'date': DateTime.fromMillisecondsSinceEpoch(
              dateMs,
            ).toIso8601String().split('T')[0],
            'type': type == 'income' ? 'Thu' : 'Chi',
            'amount': amount,
            'category': categoryName, // ← sửa ở đây
            'note': note,
          });
        }
      });
    }

    final net = totalIncome - totalExpense;

    final nf = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    final summary =
        """
Tổng thu nhập: ${nf.format(totalIncome)}
Tổng chi tiêu: ${nf.format(totalExpense)}
Tiết kiệm ròng: ${nf.format(net)}

Chi tiết chi theo danh mục:
${categoryBreakdown.entries.map((e) => "- ${e.key}: ${nf.format(e.value)}").join('\n')}

Tóm tắt theo tháng (net):
${monthlyNet.entries.map((e) => "- ${e.key}: ${nf.format(e.value)}").join('\n')}

Giao dịch gần đây (mới nhất trước):
${recentTx.map((t) => "- ${t['date']} | ${t['type']} ${nf.format(t['amount'])} | ${t['category']} | ${t['note']}").join('\n')}
""";

    return {
      'summaryText': summary.trim(),
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netSavings': net,
    };
  }
}
