import 'package:flutter_learning/10_march/hotel_model.dart';
import 'package:get/state_manager.dart';

class CounterController extends GetxController {
  Rx<int> counter = 0.obs;

  int counter2 = 0;

  void increment() {
    counter.value++;
  }

  void incrementCounter2() {
    counter2++;
    update();
  }

  // void clearFields() {
  //   counter.value = 0;
  //   counter2 = 0;
  // }
}
