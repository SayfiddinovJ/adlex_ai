import 'package:adlex_ai/screens/analysis_screen.dart';
import 'package:adlex_ai/screens/appeal_screen.dart';
import 'package:adlex_ai/screens/application_screen.dart';
import 'package:adlex_ai/screens/chat_screen.dart';
import 'package:adlex_ai/theme/app_theme.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset("assets/logo.png", height: 30, width: 30),
            SizedBox(width: 8),
            Text('ADLEX AI'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero AI Banner
            _buildHeroBanner(),
            const SizedBox(height: 24),

            // Bo'lim sarlavhasi
            const Text(
              "AI Xizmatlar",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            // 2. 2x2 Grid Services
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _buildServiceCard(
                  context,
                  title: "AI maslahati",
                  description: "Muammoni yozing, aniq modda bilan yechim oling",
                  icon: Icons.analytics_outlined,
                  iconBgColor: AppColors.lightBlue,
                  iconColor: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ChatScreen()),
                    );
                  },
                ),
                _buildServiceCard(
                  context,
                  title: "Soha & Murojaat",
                  description:
                      "Muammo qaysi sohaga tegishli va qayerga borish kerak?",
                  icon: Icons.account_balance_outlined,
                  iconBgColor: const Color(0xFFFFF9E6),
                  // Light gold/yellow background
                  iconColor: AppColors.gold,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AppealScreen()),
                    );
                  },
                ),
                _buildServiceCard(
                  context,
                  title: "Ariza Yaratish",
                  description:
                      "AI yordamida tezkor va xatosiz ariza tayyorlang",
                  icon: Icons.description_outlined,
                  iconBgColor: const Color(0xFFE6F4EA),
                  // Light green background
                  iconColor: AppColors.successGreen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApplicationScreen(),
                      ),
                    );
                  },
                ),
                _buildServiceCard(
                  context,
                  title: "Hujjat Tahlili",
                  description:
                      "Murakkab hujjatni yuklang va AI tushuntirib beradi",
                  icon: Icons.document_scanner_outlined,
                  iconBgColor: const Color(0xFFFCE8E6),
                  // Light red background
                  iconColor: AppColors.errorRed,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AnalysisScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Lex.uz Info Card
            _buildLexInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold, width: 1),
            ),
            child: const Text(
              "Lex.uz Bazasi Asosida",
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Raqamli Huquqiy Yordamchingiz",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Savolingizni bering va AI soniyalar ichida qonuniy yechim topadi.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      // AppTheme'dagi cardTheme'dan avtomatik border va ranglarni oladi
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLexInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.successGreen,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Rasmiy va Ishonchli",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Barcha tahlillar O'zbekiston Respublikasi qonun hujjatlari ma'lumotlari milliy bazasiga tayanadi.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
