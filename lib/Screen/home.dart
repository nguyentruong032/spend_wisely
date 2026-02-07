import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';
import 'acc_management.dart';
import 'expense.dart';
import 'income.dart';
import 'add_transaction.dart';
import 'chat_screen.dart';
import 'notification.dart';
import 'package:spend_wisely/Function/date_time_extension.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  User? _currentUser;
  String? _email;
  String? _username;
  double _totalBalance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  // Dữ liệu biểu đồ: index nhóm -> {income, expense}
  Map<int, Map<String, double>> _chartData = {};
  double _maxChartValue = 1000000.0;
  String _selectedPeriod = 'day'; // Mặc định là 'day' khi mở app
  List<String> _periodLabels = [];

  // ScrollController để tự động đưa ngày/tháng/năm hiện tại vào tầm nhìn
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _loadUserData();
      _fetchTransactions();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Hàm mới (copy y hệt logic từ acc_management.dart) ──
  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      setState(() {
        _email = _currentUser!.email;
      });

      String name = await FirebaseService.getUserName(_currentUser!.uid);

      if (mounted) {
        setState(() {
          _username = name;
        });
      }
    }
  }

  Future<void> _fetchTransactions() async {
    if (_currentUser == null) return;

    List<Transaction> allTransactions = await FirebaseService.getTransactions(
      _currentUser!.uid,
      'all',
    );

    DateTime now = DateTime.now();
    Map<int, Map<String, double>> newChartData = {};
    List<String> newPeriodLabels = [];
    double newMaxValue = 0.0;
    double totalIncomeSum = 0.0;
    double totalExpenseSum = 0.0;

    if (_selectedPeriod == 'day') {
      // ── NGÀY ── Hiển thị 7 ngày gần nhất
      DateTime startDate = now.subtract(const Duration(days: 6)); // 7 ngày
      Map<String, Map<String, double>> dailyData = {};

      // Khởi tạo 7 ngày
      for (int i = 0; i < 7; i++) {
        DateTime date = startDate.add(Duration(days: i));
        String key =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        dailyData[key] = {'income': 0.0, 'expense': 0.0};
      }

      // Gom dữ liệu
      for (var tx in allTransactions) {
        DateTime txDate = DateTime.fromMillisecondsSinceEpoch(tx.date);
        if (txDate.isAfter(startDate.subtract(const Duration(days: 1)))) {
          String key =
              "${txDate.year}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}";
          if (dailyData.containsKey(key)) {
            if (tx.type == 'income') {
              dailyData[key]!['income'] =
                  dailyData[key]!['income']! + tx.amount;
            } else if (tx.type == 'expense') {
              dailyData[key]!['expense'] =
                  dailyData[key]!['expense']! + tx.amount;
            }
          }
        }
      }

      // Tạo chart data (7 nhóm)
      for (int i = 0; i < 7; i++) {
        DateTime date = startDate.add(Duration(days: i));
        String key =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        double income = dailyData[key]?['income'] ?? 0.0;
        double expense = dailyData[key]?['expense'] ?? 0.0;
        newChartData[i] = {'income': income, 'expense': expense};
        newPeriodLabels.add("${date.day}/${date.month}");
        totalIncomeSum += income;
        totalExpenseSum += expense;
        newMaxValue = [
          newMaxValue,
          income,
          expense,
        ].reduce((a, b) => a > b ? a : b);
      }
    } else if (_selectedPeriod == 'month') {
      // ── THÁNG ── 6 tháng gần nhất
      Map<String, Map<String, double>> monthlyData = {};

      for (int i = 5; i >= 0; i--) {
        DateTime monthDate = DateTime(now.year, now.month - i, 1);
        String key =
            "${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}";
        monthlyData[key] = {'income': 0.0, 'expense': 0.0};
      }

      for (var tx in allTransactions) {
        DateTime txDate = DateTime.fromMillisecondsSinceEpoch(tx.date);
        String key =
            "${txDate.year}-${txDate.month.toString().padLeft(2, '0')}";
        if (monthlyData.containsKey(key)) {
          if (tx.type == 'income') {
            monthlyData[key]!['income'] =
                monthlyData[key]!['income']! + tx.amount;
          } else if (tx.type == 'expense') {
            monthlyData[key]!['expense'] =
                monthlyData[key]!['expense']! + tx.amount;
          }
        }
      }

      int index = 0;
      for (int i = 5; i >= 0; i--) {
        DateTime monthDate = DateTime(now.year, now.month - i, 1);
        String key =
            "${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}";
        double income = monthlyData[key]?['income'] ?? 0.0;
        double expense = monthlyData[key]?['expense'] ?? 0.0;
        newChartData[index] = {'income': income, 'expense': expense};
        newPeriodLabels.add("Th${monthDate.month}/${monthDate.year % 100}");
        totalIncomeSum += income;
        totalExpenseSum += expense;
        newMaxValue = [
          newMaxValue,
          income,
          expense,
        ].reduce((a, b) => a > b ? a : b);
        index++;
      }
    } else if (_selectedPeriod == 'year') {
      // ── NĂM ── 5 năm gần nhất
      Map<int, Map<String, double>> yearlyData = {};

      for (int i = 4; i >= 0; i--) {
        int year = now.year - i;
        yearlyData[year] = {'income': 0.0, 'expense': 0.0};
      }

      for (var tx in allTransactions) {
        DateTime txDate = DateTime.fromMillisecondsSinceEpoch(tx.date);
        int year = txDate.year;
        if (yearlyData.containsKey(year)) {
          if (tx.type == 'income') {
            yearlyData[year]!['income'] =
                yearlyData[year]!['income']! + tx.amount;
          } else if (tx.type == 'expense') {
            yearlyData[year]!['expense'] =
                yearlyData[year]!['expense']! + tx.amount;
          }
        }
      }

      int index = 0;
      for (int i = 4; i >= 0; i--) {
        int year = now.year - i;
        double income = yearlyData[year]?['income'] ?? 0.0;
        double expense = yearlyData[year]?['expense'] ?? 0.0;
        newChartData[index] = {'income': income, 'expense': expense};
        newPeriodLabels.add(year.toString());
        totalIncomeSum += income;
        totalExpenseSum += expense;
        newMaxValue = [
          newMaxValue,
          income,
          expense,
        ].reduce((a, b) => a > b ? a : b);
        index++;
      }
    }

    setState(() {
      _totalExpense = totalExpenseSum;
      _totalIncome = totalIncomeSum;
      _totalBalance = totalIncomeSum - totalExpenseSum;
      _chartData = newChartData;
      _periodLabels = newPeriodLabels;
      _maxChartValue = newMaxValue > 0 ? newMaxValue * 1.25 : 1000000.0;
    });

    // Tự động scroll để ngày/tháng/năm hiện tại nằm chính giữa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _chartData.isNotEmpty) {
        const double groupWidth = 90.0;
        final int currentIndex = _chartData.length - 1;

        double targetOffset =
            (currentIndex * groupWidth) -
            (MediaQuery.of(context).size.width / 2) +
            (groupWidth / 2);

        double maxOffset = _scrollController.position.maxScrollExtent;
        if (targetOffset < 0) targetOffset = 0;
        if (targetOffset > maxOffset) targetOffset = maxOffset;

        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ExpenseScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddTransactionScreen()),
        ).then((_) {
          setState(() => _selectedIndex = 0);
          _fetchTransactions();
        });
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => IncomeScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AccountManagementScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Số dư hiện có: ${_totalBalance.toStringAsFixed(0)} đ",
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black54),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              // Card Ví của tôi
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5CAE9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Ví của tôi",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.wallet, size: 40, color: Colors.brown),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _username ?? "Không có tên", // ← sửa
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _email ?? "Không có email", // ← sửa
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Biểu đồ
              Container(
                height: 460,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPeriod,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            items: const [
                              DropdownMenuItem(
                                value: 'day',
                                child: Text('Ngày'),
                              ),
                              DropdownMenuItem(
                                value: 'month',
                                child: Text('Tháng'),
                              ),
                              DropdownMenuItem(
                                value: 'year',
                                child: Text('Năm'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedPeriod = value);
                                _fetchTransactions();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Thu nhập',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Chi tiêu',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            controller: _scrollController,
                            child: SizedBox(
                              width: _chartData.length * 90.0 + 80,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: _maxChartValue,
                                  minY: 0,
                                  groupsSpace: 36,
                                  barGroups: _chartData.entries.map((
                                    MapEntry<int, Map<String, double>> entry,
                                  ) {
                                    final int index = entry.key;
                                    final Map<String, double> values =
                                        entry.value;
                                    final double income =
                                        values['income'] ?? 0.0;
                                    final double expense =
                                        values['expense'] ?? 0.0;
                                    const double rodWidth = 24;

                                    return BarChartGroupData(
                                      x: index,
                                      barsSpace: 8,
                                      barRods: [
                                        BarChartRodData(
                                          toY: income,
                                          color: Colors.green.shade600,
                                          width: rodWidth,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(8),
                                              ),
                                        ),
                                        BarChartRodData(
                                          toY: expense,
                                          color: Colors.red.shade600,
                                          width: rodWidth,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(8),
                                              ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          int index = value.toInt();
                                          if (index >= 0 &&
                                              index < _periodLabels.length) {
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(
                                                _periodLabels[index],
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: false,
                                        reservedSize: 50,
                                        getTitlesWidget: (value, meta) => Text(
                                          _formatCurrency(value),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: _maxChartValue / 5,
                                  ),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      fitInsideHorizontally: true,
                                      fitInsideVertically: true,
                                      tooltipRoundedRadius: 8,
                                      tooltipPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      getTooltipItem:
                                          (group, groupIndex, rod, rodIndex) {
                                            String label = rodIndex == 0
                                                ? 'Thu nhập'
                                                : 'Chi tiêu';
                                            Color textColor = rodIndex == 0
                                                ? Colors.green[800]!
                                                : Colors.red[800]!;
                                            return BarTooltipItem(
                                              '$label\n${_formatCurrency(rod.toY)}',
                                              TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Trục Y cố định bên trái
                          Positioned(
                            top: 0,
                            bottom: 40,
                            left: 0,
                            width: 60,
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (i) {
                                  double value = _maxChartValue * (5 - i) / 5;
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        _formatCurrency(value),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 70,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatScreen()),
              ),
              backgroundColor: const Color(0xFF1976D2),
              child: Stack(
                children: [
                  const Icon(Icons.chat_bubble, color: Colors.white, size: 28),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: MediaQuery.of(context).size.width / 2 - 30,
            child: FloatingActionButton(
              onPressed: () => _onItemTapped(2),
              backgroundColor: Colors.greenAccent.shade400,
              child: const Icon(Icons.add, size: 35, color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, "Trang chủ", 0),
                _buildNavItem(Icons.money_off, "Chi tiêu", 1),
                const SizedBox(width: 40),
                _buildNavItem(Icons.account_balance_wallet, "Thu nhập", 3),
                _buildNavItem(Icons.person, "Tài khoản", 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    double absValue = value.abs();
    String sign = value < 0 ? '-' : '';

    if (absValue >= 1000000000) {
      double ty = absValue / 1000000000;
      return '$sign${ty.toStringAsFixed(ty >= 10 ? 0 : 1)}ty';
    } else if (absValue >= 1000000) {
      double tr = absValue / 1000000;
      return '$sign${tr.toStringAsFixed(tr >= 10 ? 0 : 1)}tr';
    } else if (absValue >= 1000) {
      double k = absValue / 1000;
      return '$sign${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    } else {
      return '$sign${absValue.toStringAsFixed(0)}';
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE3F2FD).withOpacity(0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF1976D2)
                  : Colors.grey.shade600,
              size: isSelected ? 26 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF1976D2)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
