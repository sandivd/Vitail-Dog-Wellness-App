import 'vitail_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<bool?> showDogPhotoSheet(BuildContext context, {ImageProvider? photo}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VitailColors.of(context).background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VitailColors.of(context).border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                photo == null ? 'Add a dog photo' : 'Change dog photo',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: VitailColors.of(context).ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a favourite photo from your phone.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: VitailColors.of(context).muted,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: VitailColors.of(context).border,
                  backgroundImage: photo,
                  child: photo == null
                      ? SvgPicture.asset(
                          'assets/icons/onboarding-camera.svg',
                          width: 24,
                          height: 24,
                          colorFilter: VitailColors.of(context).isDark
                              ? ColorFilter.mode(
                                  VitailColors.of(context).muted,
                                  BlendMode.srcIn,
                                )
                              : null,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VitailColors.of(context).tint(
                    const Color(0xFFCD533B),
                    VitailColors.of(context).coral,
                  ),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Choose from photos',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: VitailColors.of(context).muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
