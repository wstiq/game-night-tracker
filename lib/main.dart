import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/deposits_screen.dart';
import 'screens/debtors_screen.dart';
import 'screens/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Night Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;

  static const _screens = [
    HomeScreen(),
    DepositsScreen(),
    DebtorsScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyedSubtree(key: ValueKey(_idx), child: _screens[_idx]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.nights_stay_outlined),
              selectedIcon: Icon(Icons.nights_stay),
              label: 'Вечера'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Депозиты'),
          NavigationDestination(
              icon: Icon(Icons.warning_amber_outlined),
              selectedIcon: Icon(Icons.warning_amber),
              label: 'Должники'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'История'),
        ],
      ),
    );
  }
}
