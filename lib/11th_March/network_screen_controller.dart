import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/route_manager.dart';
import 'package:http/http.dart' as http;

class NetworkScreenController extends GetxController {
  dynamic data;
  bool isLoading = false;

  showLoader() {
    isLoading = true;
    // update();
  }

  hideLoader() {
    isLoading = false;
    // update();
  }

  Future<void> getTodos() async {
    showLoader();

    http.Response result =
        await http.get(Uri.parse('https://jsonplaceholder.typicode.com/todos'));

    await Future.delayed(Duration(seconds: 2));

    hideLoader();

    if (result.statusCode == 200) {
      
      String value = result.body;

      data = value;
      Get.snackbar(
        'Success',
        '',
        colorText: Colors.white,
        backgroundColor: Colors.greenAccent,
        icon: const Icon(Icons.check),
      );
    } else {
      Get.snackbar(
        'Error',
        'Something went wrong!',
        colorText: Colors.white,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.error),
      );
    }

    update();
    //last line of this method
  }
}
