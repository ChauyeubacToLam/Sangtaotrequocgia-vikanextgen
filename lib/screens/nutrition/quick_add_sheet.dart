import 'package:flutter/material.dart';

import '../../nutrition/nutrition_store.dart';
import '../../widgets/tk/tk.dart';
import 'barcode_screen.dart';
import 'create_dish_screen.dart';
import 'create_food_screen.dart';
import 'fasting_screen.dart';
import 'food_search_screen.dart';
import 'nutrition_screen.dart';
import 'photo_food_screen.dart';

Future<void> showQuickAddSheet(
  BuildContext context, {
  required DateTime day,
  required Future<void> Function() onChanged,
}) {
  final meal = mealSlotForHour(DateTime.now().hour);
  Future<void> push(BuildContext sheet, Widget page) async {
    Navigator.of(sheet).pop();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    await onChanged();
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tk.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Hôm nay bạn ăn gì?',
                      style: Tk.text(22, weight: FontWeight.w900)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                _Big(
                    Icons.search_rounded,
                    'Nhập món ăn',
                    const Color(0xFFE3F7F4),
                    () => push(sheet, FoodSearchScreen(day: day, meal: meal))),
                _Big(
                    Icons.playlist_add_rounded,
                    'Nhập nhiều món',
                    const Color(0xFFEDE7FB),
                    () => push(sheet,
                        FoodSearchScreen(day: day, meal: meal, multi: true))),
                _Big(
                    Icons.mic_rounded,
                    'Nhập bằng giọng nói',
                    const Color(0xFFE6F1FD),
                    () => push(
                        sheet,
                        FoodSearchScreen(
                            day: day,
                            meal: meal,
                            multi: true,
                            startVoice: true))),
                _Big(
                    Icons.qr_code_scanner_rounded,
                    'Quét mã vạch',
                    const Color(0xFFFFF1E3),
                    () => push(sheet, BarcodeScreen(day: day, meal: meal))),
                _Big(
                    Icons.photo_camera_rounded,
                    'Chụp ảnh món ăn',
                    const Color(0xFFEDF8F0),
                    () => push(sheet, PhotoFoodScreen(day: day, meal: meal))),
                _Big(
                    Icons.document_scanner_rounded,
                    'Quét nhãn dinh dưỡng',
                    const Color(0xFFFDECEC),
                    () => push(sheet, const CreateFoodScreen(scanLabel: true))),
              ],
            ),
            const SizedBox(height: 16),
            Text('CÔNG CỤ KHÁC', style: Tk.eyebrow()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Small(Icons.menu_book_rounded, 'Tạo công thức',
                    () => push(sheet, const CreateDishScreen())),
                _Small(Icons.view_list_rounded, 'Tạo thực đơn',
                    () => push(sheet, const CreateDishScreen(menu: true))),
                _Small(Icons.add_box_rounded, 'Tạo thực phẩm',
                    () => push(sheet, const CreateFoodScreen())),
                _Small(Icons.water_drop_rounded, 'Uống nước 250 ml', () async {
                  Navigator.of(sheet).pop();
                  await NutritionStore.instance
                      .update(day, (l) => l.waterMl += 250);
                  await onChanged();
                }),
                _Small(Icons.monitor_weight_rounded, 'Cân nặng', () async {
                  Navigator.of(sheet).pop();
                  final kg = await showWeightDialog(context, null);
                  if (kg == null) return;
                  await NutritionStore.instance.logWeight(day, kg);
                  await onChanged();
                }),
                _Small(Icons.timer_rounded, 'Nhịn ăn',
                    () => push(sheet, const FastingScreen())),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Big extends StatelessWidget {
  const _Big(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: Tk.ink),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Tk.text(13.5, weight: FontWeight.w800, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Small extends StatelessWidget {
  const _Small(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Tk.primary),
      label: Text(label, style: Tk.text(13.5, weight: FontWeight.w700)),
      onPressed: onTap,
    );
  }
}
