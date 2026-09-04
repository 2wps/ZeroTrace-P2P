import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SessionLockOverlay extends StatefulWidget {
  final VoidCallback onUnlock;
  final String correctPin;

  const SessionLockOverlay({
    super.key,
    required this.onUnlock,
    this.correctPin = '0000',
  });

  @override
  State<SessionLockOverlay> createState() => _SessionLockOverlayState();
}

class _SessionLockOverlayState extends State<SessionLockOverlay> {
  String _enteredPin = '';
  bool _hasError = false;

  void _handleNumberPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _hasError = false;
      });
      HapticFeedback.lightImpact();

      if (_enteredPin.length == 4) {
        if (_enteredPin == widget.correctPin || widget.correctPin == '0000') {
          HapticFeedback.mediumImpact();
          widget.onUnlock();
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _hasError = true;
            _enteredPin = '';
          });
        }
      }
    }
  }

  void _handleBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _hasError = false;
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF162032),
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                ),
                child: const Icon(Icons.lock, color: Color(0xFF10B981), size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'الجلسة مؤمنة برمز المرور',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                _hasError ? 'رمز الـ PIN غير صحيح، حاول ثانية' : 'أدخل رمز الـ PIN المكون من 4 أرقام لفتح الجلسة (الافتراضي 0000)',
                style: TextStyle(fontSize: 12, color: _hasError ? Colors.redAccent : Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? const Color(0xFF10B981) : Colors.transparent,
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              // Keypad
              SizedBox(
                width: 260,
                child: Column(
                  children: [
                    for (var row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['', '0', '⌫'],
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: row.map((key) {
                            if (key == '') return const SizedBox(width: 60, height: 60);
                            if (key == '⌫') {
                              return GestureDetector(
                                onTap: _handleBackspace,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF162032),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.backspace, color: Colors.white70, size: 20),
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () => _handleNumberPress(key),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF162032),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    key,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
