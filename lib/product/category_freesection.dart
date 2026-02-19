import 'package:flutter/material.dart';

class CategoryFreesection extends StatefulWidget {
  const CategoryFreesection({super.key});

  @override
  State<CategoryFreesection> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<CategoryFreesection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Categories",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B5B95), // Soft purple
            ),
          ),
          const SizedBox(height: 12),
          // ✨ 3 PEACEFUL SECTIONS
          Row(
            children: [
              // Panchangi - Soft Peach
              Expanded(
                child: _buildCategoryCard(
                  icon: Icons.today_rounded,
                  title: "Panchangi",
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF8EDE8), // Light peach
                      Color(0xFFF0D7C9),
                    ],
                  ),
                  iconColor: const Color(0xFFE8B4A3),
                ),
              ),
              const SizedBox(width: 12),
              // Incense - Soft Lavender
              Expanded(
                child: _buildCategoryCard(
                  icon: Icons.whatshot_rounded,
                  title: "Incense",
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF1E8FB), // Light lavender
                      Color(0xFFE1D5F2),
                    ],
                  ),
                  iconColor: const Color(0xFFBEA8D1),
                ),
              ),
              const SizedBox(width: 12),
              // Diya - Soft Mint
              Expanded(
                child: _buildCategoryCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: "Diya",
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE8F5E8), // Light mint
                      Color(0xFFDCF0D9),
                    ],
                  ),
                  iconColor: const Color(0xFF9FC89F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {}, // Add navigation later
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF5A5566).withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
