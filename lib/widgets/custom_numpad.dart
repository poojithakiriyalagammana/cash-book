import 'package:flutter/material.dart';
// import 'dart:math';

class CustomNumpad extends StatelessWidget {
  final TextEditingController controller;
  final Function onSubmit;
  final bool isDarkMode;

  const CustomNumpad({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Define colors based on theme
    final Color backgroundColor =
        isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final Color regularButtonColor =
        isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
    final Color functionButtonColor =
        isDarkMode ? const Color(0xFF444444) : const Color(0xFFDCDCDC);
    final Color actionButtonColor =
        isDarkMode ? const Color(0xFF0D7ECA) : const Color(0xFF2196F3);
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color functionTextColor =
        isDarkMode ? Colors.white70 : Colors.black54;

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonSize = constraints.maxWidth / 4 - 8;
        final buttonHeight = buttonSize * 0.4;

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black26 : Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // First row: AC, ÷, ×, ⌫
                _buildButtonRow(
                  [
                    KeypadButton(
                      text: 'AC',
                      textColor: isDarkMode ? Colors.redAccent : Colors.red,
                      backgroundColor: functionButtonColor,
                      onPressed: () {
                        controller.clear();
                      },
                    ),
                    KeypadButton(
                      text: '÷',
                      textColor: functionTextColor,
                      backgroundColor: functionButtonColor,
                      onPressed: () => _appendText(' ÷ '),
                    ),
                    KeypadButton(
                      text: '×',
                      textColor: functionTextColor,
                      backgroundColor: functionButtonColor,
                      onPressed: () => _appendText(' × '),
                    ),
                    KeypadButton(
                      text: '⌫',
                      textColor: functionTextColor,
                      backgroundColor: functionButtonColor,
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          controller.text = controller.text.substring(
                            0,
                            controller.text.length - 1,
                          );
                        }
                      },
                    ),
                  ],
                  buttonSize,
                  buttonHeight,
                ),

                // Second row: 7, 8, 9, -
                _buildButtonRow(
                  [
                    KeypadButton(
                      text: '7',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('7'),
                    ),
                    KeypadButton(
                      text: '8',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('8'),
                    ),
                    KeypadButton(
                      text: '9',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('9'),
                    ),
                    KeypadButton(
                      text: '-',
                      textColor: functionTextColor,
                      backgroundColor: functionButtonColor,
                      onPressed: () => _appendText(' - '),
                    ),
                  ],
                  buttonSize,
                  buttonHeight,
                ),

                // Third row: 4, 5, 6, +
                _buildButtonRow(
                  [
                    KeypadButton(
                      text: '4',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('4'),
                    ),
                    KeypadButton(
                      text: '5',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('5'),
                    ),
                    KeypadButton(
                      text: '6',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('6'),
                    ),
                    KeypadButton(
                      text: '+',
                      textColor: functionTextColor,
                      backgroundColor: functionButtonColor,
                      onPressed: () => _appendText(' + '),
                    ),
                  ],
                  buttonSize,
                  buttonHeight,
                ),

                // Fourth row: 1, 2, 3, =
                _buildButtonRow(
                  [
                    KeypadButton(
                      text: '1',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('1'),
                    ),
                    KeypadButton(
                      text: '2',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('2'),
                    ),
                    KeypadButton(
                      text: '3',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('3'),
                    ),
                    KeypadButton(
                      text: '=',
                      textColor: functionTextColor,
                      backgroundColor: functionButtonColor,
                      onPressed: () {
                        // Calculate the result and update the controller
                        calculateResult();
                        // onSubmit();
                      },
                    ),
                  ],
                  buttonSize,
                  buttonHeight,
                ),

                // Fifth row: 00, 0, ., Submit button
                _buildButtonRow(
                  [
                    KeypadButton(
                      text: '00',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('00'),
                    ),
                    KeypadButton(
                      text: '0',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('0'),
                    ),
                    KeypadButton(
                      text: '.',
                      textColor: textColor,
                      backgroundColor: regularButtonColor,
                      onPressed: () => _appendText('.'),
                    ),
                    KeypadButton(
                      text: '',
                      icon: Icons.arrow_forward,
                      textColor: Colors.white,
                      backgroundColor: actionButtonColor,
                      onPressed: () {
                        // Calculate the result and update the controller
                        calculateResult();
                        // onSubmit();
                      },
                    ),
                  ],
                  buttonSize,
                  buttonHeight,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonRow(
      List<KeypadButton> buttons, double buttonSize, double buttonHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: buttons.map((button) {
          return _buildButton(
            button.text,
            backgroundColor: button.backgroundColor,
            textColor: button.textColor,
            icon: button.icon,
            onPressed: button.onPressed,
            size: buttonSize,
            height: buttonHeight,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(
    String text, {
    required Color backgroundColor,
    required Color textColor,
    IconData? icon,
    required Function onPressed,
    required double size,
    required double height,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: () => onPressed(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: textColor, size: 24)
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _appendText(String text) {
    final currentText = controller.text;
    final currentPosition = controller.selection.start;

    // Handle cursor position
    if (currentPosition >= 0) {
      final newText = currentText.substring(0, currentPosition) +
          text +
          currentText.substring(currentPosition);
      controller.text = newText;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: currentPosition + text.length),
      );
    } else {
      // If no cursor position, just append to the end
      controller.text = currentText + text;
    }
  }

  // New function to calculate the result
  void calculateResult() {
    try {
      String expression = controller.text;

      // Replace the symbols with their JavaScript equivalents
      expression = expression.replaceAll('×', '*');
      expression = expression.replaceAll('÷', '/');
      expression = expression.replaceAll('%', '%');

      // Parse the expression and calculate the result
      final result = evaluateExpression(expression);

      // Update the controller with the result
      controller.text = result.toString();

      // Set the cursor at the end
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    } catch (e) {
      // If there's an error in calculation, keep the current text
      print('Error calculating: $e');
    }
  }

  // Simple expression evaluator
  double evaluateExpression(String expression) {
    // This is a basic evaluator - in a real app, you might want to use a more robust parser
    try {
      // Split the expression into components
      expression = expression.replaceAll(' ', ''); // Remove spaces

      // Basic implementation to handle addition, subtraction, multiplication, division, and modulo
      // This is a simple implementation and doesn't handle all cases properly
      List<String> tokens = [];
      String currentNumber = '';

      for (int i = 0; i < expression.length; i++) {
        final char = expression[i];
        if (char == '+' ||
            char == '-' ||
            char == '*' ||
            char == '/' ||
            char == '%') {
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          tokens.add(char);
        } else {
          currentNumber += char;
        }
      }

      if (currentNumber.isNotEmpty) {
        tokens.add(currentNumber);
      }

      // Handle multiplication, division, and modulo first
      for (int i = 1; i < tokens.length - 1; i += 2) {
        if (tokens[i] == '*' || tokens[i] == '/' || tokens[i] == '%') {
          final a = double.parse(tokens[i - 1]);
          final b = double.parse(tokens[i + 1]);
          double result;

          if (tokens[i] == '*') {
            result = a * b;
          } else if (tokens[i] == '/') {
            result = a / b;
          } else {
            // modulo
            result = a % b;
          }

          tokens[i - 1] = result.toString();
          tokens.removeAt(i);
          tokens.removeAt(i);
          i -= 2;
        }
      }

      // Handle addition and subtraction
      double result = double.parse(tokens[0]);
      for (int i = 1; i < tokens.length; i += 2) {
        final b = double.parse(tokens[i + 1]);
        if (tokens[i] == '+') {
          result += b;
        } else if (tokens[i] == '-') {
          result -= b;
        }
      }

      // Return the result, removing decimal point if it's a whole number
      if (result == result) {
        return result;
      }
      return result;
    } catch (e) {
      print('Error in expression evaluation: $e');
      throw Exception('Invalid expression');
    }
  }
}

// Helper class to structure button data
class KeypadButton {
  final String text;
  final Color textColor;
  final Color backgroundColor;
  final Function onPressed;
  final IconData? icon;

  KeypadButton({
    required this.text,
    required this.textColor,
    required this.backgroundColor,
    required this.onPressed,
    this.icon,
  });
}
