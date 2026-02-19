import 'package:flutter/material.dart';
import 'package:flutter_learning/11th_March/counter_controller.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';

class CounterWithGetx extends StatefulWidget {
  const CounterWithGetx({super.key});

  @override
  State<CounterWithGetx> createState() => _CounterWithGetxState();
}

class _CounterWithGetxState extends State<CounterWithGetx> {
  CounterController controller = Get.put(CounterController());

  @override
  void dispose() {
    // controller.clearFields();
    // controller.dispose();
    Get.delete<CounterController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          children: [
            Obx(
              () => Text(
                controller.counter.value.toString(),
                style: TextStyle(fontSize: 30),
              ),
            ),

            GetBuilder<CounterController>(
              builder: (CounterController controller) {
                return Text(
                  controller.counter2.toString(),
                  style: TextStyle(fontSize: 30),
                );
              },
            ),
            
            Row(
              children: [
                ElevatedButton(
                    onPressed: () {
                      controller.increment();
                    },
                    child: Icon(Icons.add)),
                ElevatedButton(
                    onPressed: () {
                      controller.incrementCounter2();
                    },
                    child: Icon(Icons.add_a_photo))
              ],
            )
          ],
        ),
      ),
    );
  }
}
