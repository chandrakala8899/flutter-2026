import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  bool showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            spacing: 16,
            children: [
              TextField(
                decoration: InputDecoration(
                    labelText: 'Username', border: OutlineInputBorder()),
                // inputFormatters: [FilteringTextInputFormatter.allow(regex)],
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            if (showPassword) {
                              showPassword = false;
                            } else {
                              showPassword = true;
                            }
                          });
                        },
                        icon: Icon(showPassword
                            ? Icons.visibility_off
                            : Icons.visibility))),
                // inputFormatters: [FilteringTextInputFormatter.allow(regex)],
                obscureText: showPassword,
              ),
              ElevatedButton(onPressed: () {}, child: Text('Elevated Button')),
              TextButton(onPressed: () {}, child: Text('Text Button')),
              IconButton(onPressed: () {}, icon: Icon(Icons.add)),
              DropdownButton(
                hint: Text('Select'),
                items: [
                  DropdownMenuItem(value: 'Option 1', child: Text('Option 1')),
                  DropdownMenuItem(value: 'Option 2', child: Text('Option 2')),
                  DropdownMenuItem(value: 'Option 3', child: Text('Option 3')),
                ],
                onChanged: (val) {},
                icon: Icon(Icons.arrow_downward),
              ),
              PopupMenuButton(
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(value: 'Option 1', child: Text('Option 1')),
                    PopupMenuItem(value: 'Option 2', child: Text('Option 2')),
                    PopupMenuItem(value: 'Option 3', child: Text('Option 3')),
                  ];
                },
              ),
              buildRadioButtons(),
              buildCheckBoxes(),
            ],
          ),
        ),
      ),
    );
  }

  String? groupValue = 'GV';

  bool? isChecked = false;

  Widget buildCheckBoxes() {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    isChecked = val;
                  });
                }),
            Text('Male'),
          ],
        ),
        Row(
          children: [
            Radio(
                value: 'Female',
                groupValue: groupValue,
                onChanged: (val) {
                  setState(() {
                    groupValue = val;
                  });
                }),
            Text('Female'),
          ],
        ),
        Row(
          children: [
            Radio(
                value: 'Others',
                groupValue: groupValue,
                onChanged: (val) {
                  setState(() {
                    groupValue = val;
                  });
                }),
            Text('Others'),
          ],
        )
      ],
    );
  }

  Widget buildRadioButtons() {
    return Column(
      children: [
        Row(
          children: [
            Radio(
                value: 'Male',
                groupValue: groupValue,
                onChanged: (val) {
                  setState(() {
                    groupValue = val;
                  });
                }),
            Text('Male'),
          ],
        ),
        Row(
          children: [
            Radio(
                value: 'Female',
                groupValue: groupValue,
                onChanged: (val) {
                  setState(() {
                    groupValue = val;
                  });
                }),
            Text('Female'),
          ],
        ),
        Row(
          children: [
            Radio(
                value: 'Others',
                groupValue: groupValue,
                onChanged: (val) {
                  setState(() {
                    groupValue = val;
                  });
                }),
            Text('Others'),
          ],
        )
      ],
    );
  }
}
