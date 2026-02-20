import 'package:flutter/material.dart';
import 'package:flutter_learning/colors.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_learning/product/model/birthdetails_model.dart';
import 'package:flutter_learning/product/model/panchangresponse_model.dart';
import 'package:flutter_learning/product/product_service.dart/production_api.dart';

class CategoryFreesection extends StatefulWidget {
  const CategoryFreesection({super.key});

  @override
  State<CategoryFreesection> createState() => _CategoryFreesectionState();
}

class _CategoryFreesectionState extends State<CategoryFreesection> {
  void _openPanchangDialog() {
    final latController = TextEditingController();
    final longController = TextEditingController();

    DateTime? selectedDateTime;
    bool isLoading = false;
    String? selectedLocationName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              title: const Center(
                child: Text(
                  "Enter  Details",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color.fromARGB(255, 15, 2, 49),
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// ================= DATE & TIME =================
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          initialDate: DateTime.now(),
                        );

                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );

                          if (time != null) {
                            setStateDialog(() {
                              selectedDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, color: primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedDateTime == null
                                    ? "Select Date & Time"
                                    : "${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year} "
                                        "${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// ================= USE CURRENT LOCATION =================
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          setStateDialog(() => isLoading = true);

                          final position =
                              await ProductApiService.getCurrentLocation();

                          if (position != null) {
                            latController.text = position.latitude.toString();
                            longController.text = position.longitude.toString();

                            List<Placemark> placemarks =
                                await placemarkFromCoordinates(
                                    position.latitude, position.longitude);
                            Placemark place = placemarks.first;
                            selectedLocationName =
                                "${place.locality}, ${place.administrativeArea}";
                          }

                          setStateDialog(() => isLoading = false);
                        },
                        icon: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Use Current Location",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// ================= SELECTED LOCATION NAME =================
                    if (selectedLocationName != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedLocationName!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 15),

                    /// ================= LATITUDE FIELD =================
                    if (latController.text.isNotEmpty)
                      TextField(
                        controller: latController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Latitude",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    /// ================= LONGITUDE FIELD =================
                    if (longController.text.isNotEmpty)
                      TextField(
                        controller: longController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Longitude",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    /// ================= LOADING =================
                    if (isLoading)
                      CircularProgressIndicator(
                        color: primaryColor,
                      ),
                  ],
                ),
              ),

              /// ================= ACTION BUTTONS =================
              actionsPadding: const EdgeInsets.symmetric(horizontal: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (selectedDateTime == null ||
                        latController.text.isEmpty ||
                        longController.text.isEmpty) {
                      return;
                    }

                    setStateDialog(() => isLoading = true);

                    final birthDetails = BirthDetailsModel(
                      dateTime: selectedDateTime!,
                      latitude: double.parse(latController.text),
                      longitude: double.parse(longController.text),
                    );

                    final result = await ProductApiService.getPanchang(
                        birthDetails: birthDetails);

                    setStateDialog(() => isLoading = false);
                    Navigator.pop(context);

                    if (result != null) {
                      _showResultDialog(result);
                    }
                  },
                  child: const Text(
                    "Submit",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResultDialog(PanchangSummaryModel result) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 8,
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Main Dialog Container
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.8),
                      primaryColor.withOpacity(0.5)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Today's Panchang",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (result.tithi != null && result.tithi!.isNotEmpty)
                      _resultTile("Tithi", result.tithi),
                    if (result.nakshatra != null &&
                        result.nakshatra!.isNotEmpty)
                      _resultTile("Nakshatra", result.nakshatra),
                    if (result.rahuKaal != null && result.rahuKaal!.isNotEmpty)
                      _resultTile("Rahu Kaal", result.rahuKaal),
                    if (result.festival != null && result.festival!.isNotEmpty)
                      _resultTile("Festival", result.festival),
                    if (result.moonrise != null && result.moonrise!.isNotEmpty)
                      _resultTile("Moonrise", result.moonrise),
                    if (result.moonset != null && result.moonset!.isNotEmpty)
                      _resultTile("Moonset", result.moonset),
                    if (result.sunrise != null && result.sunrise!.isNotEmpty)
                      _resultTile("Sunrise", result.sunrise),
                    if (result.sunset != null && result.sunset!.isNotEmpty)
                      _resultTile("Sunset", result.sunset),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // Close button
            ],
          ),
        );
      },
    );
  }

  Widget _resultTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _categoryCard(Icons.today, "Panchang", _openPanchangDialog),
              _categoryCard(Icons.auto_awesome, "Horoscope", () {}),
              _categoryCard(Icons.star, "Kundli", () {}),
            ],
          )
        ],
      ),
    );
  }

  Widget _categoryCard(IconData icon, String title, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
