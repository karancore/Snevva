import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../../Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import '../../Controllers/local_storage_manager.dart';
import '../../Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import '../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/CommonWidgets/custom_outlined_button.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../Widgets/CommonWidgets/common_date_widget.dart';
import '../../Widgets/ProfileSetupAndQuestionnaire/height_and_weight_field.dart';
import '../../consts/consts.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {

  final localStorageManager = Get.find<LocalStorageManager>();
  final initialProfileController = Get.put(ProfileSetupController());

  final controller = Get.put(EditprofileController());

  @override
  void initState() {
    super.initState();

    print(localStorageManager.userMap);
    print(localStorageManager.userGoalDataMap);

    /// Initialize values from localStorageManager
    controller.name = localStorageManager.userMap['Name']?.toString() ?? '';
    controller.email = localStorageManager.userMap['Email']?.toString() ?? '';
    controller.phoneNumber =
        localStorageManager.userMap['PhoneNumber']?.toString() ?? '';

    print('Edit Profile Screen phone : ${controller.phoneNumber}');

    final heightValue =
        localStorageManager.userGoalDataMap['HeightData']?['Value'];

    controller.heightValue =
        (heightValue is num) ? heightValue.toStringAsFixed(2) : '';

    print(localStorageManager.userGoalDataMap['HeightData']?['Value']);
    print(controller.heightValue);

    final weightValue =
        localStorageManager.userGoalDataMap['WeightData']?['Value'];
    controller.weightValue =
        (weightValue is num) ? weightValue.toStringAsFixed(2) : '';

    controller.gender.value =
        (localStorageManager.userMap['Gender']?.toString() ?? '');

    controller.occupation =
        localStorageManager.userMap['OccupationData']?['Name']?.toString() ??
        '';
    controller.address =
        localStorageManager.userMap['AddressByUser']?.toString() ?? '';

    final day = localStorageManager.userMap['DayOfBirth'];
    final month = localStorageManager.userMap['MonthOfBirth'];
    final year = localStorageManager.userMap['YearOfBirth'];

    if (day != null && month != null && year != null) {
      controller.dob = DateTime(year, month, day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String heightValue;
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight4PercentOpacity,

        centerTitle: true,
        title: Text(
          "Edit Profile",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: white,
          ),
        ),

        // Conditionally show leading drawer icon
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: SvgPicture.asset(
                  isDarkMode ? drawerIconWhite : drawerIcon,
                  color: white,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),

        // Conditionally show close (cross) icon
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: SizedBox(
                height: 24,
                width: 24,
                child: Icon(
                  Icons.clear,
                  size: 21,
                  color: white, // Adapt to theme
                ),
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: height * 0.28,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: height * 0.20,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                  Positioned(
                    top: height * 0.1,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          SizedBox(
                            height: height * 0.18,
                            width: width * 0.35,

                            child: Obx(() {
                              final pickedFile =
                                  initialProfileController.pickedImage.value;
                              return CircleAvatar(
                                radius: 60,
                                backgroundImage:
                                    pickedFile != null
                                        ? FileImage(pickedFile)
                                        : AssetImage(profileMainImg)
                                            as ImageProvider,
                              );
                            }),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: IconButton(
                              onPressed: () async {
                                await initialProfileController
                                    .pickImageFromGallery();
                              },
                              icon: SizedBox(
                                height: 32,
                                width: 32,
                                child: CircleAvatar(
                                  backgroundColor: AppColors.primaryColor,
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: padding20px,
                  vertical: 5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Example for "Name"
                    AutoSizeText(
                      'Name',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap:
                          () => controller.showEditFieldDialog(
                            context,
                            title:
                                "Enter your full name, or update it if you're feeling like a rebrand.",
                            fieldKey: "Name",
                            initialValue:
                                localStorageManager.userMap['Name']
                                    ?.toString() ??
                                '',
                            onUpdated:
                                () => setState(() {
                                  localStorageManager.userMap['Name'] =
                                      controller.name;
                                }),
                          ),

                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),

                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Obx(
                                () => Text(
                                  localStorageManager.userMap['Name']
                                          ?.toString() ??
                                      'Enter your name',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.white60
                                            : Colors.black54,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: defaultSize - 10),

                    AutoSizeText(
                      'Email',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // SizedBox(height: defaultSize - 20),
                    // Material(
                    //   elevation: 1,
                    //   color:
                    //       isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                    //   borderRadius: BorderRadius.circular(4),
                    //   child: TextFormField(
                    //     initialValue: localStorageManager.userMap['Email']?.toString() ?? '',
                    //     decoration: InputDecoration(
                    //       // labelText: 'Name',
                    //       hintText: "Your inbox is waiting! We’ll use this to send you important updates, but don’t worry—we won’t spam you!",
                    //       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    //     ),
                    //   ),
                    // ),
                    InkWell(
                      onTap:
                          () => controller.showEditFieldDialog(
                            context,
                            title:
                                "Your inbox is waiting! We’ll use this to send you important updates, but don’t worry—we won’t spam you!",
                            fieldKey: "Email",
                            initialValue:
                                localStorageManager.userMap['Email']
                                    ?.toString() ??
                                '',
                            onUpdated:
                                () => setState(() {
                                  controller.email =
                                      controller
                                          .email; // redundant but consistent
                                  localStorageManager.userMap['Email'] =
                                      controller.email;
                                }),
                          ),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),

                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Obx(
                                () => Text(
                                  localStorageManager.userMap['Email']
                                          ?.toString() ??
                                      'Enter your email',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.white60
                                            : Colors.black54,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: defaultSize - 10),
                    AutoSizeText(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap:
                          () => controller.showEditFieldDialog(
                            context,
                            title:
                                "Stay connected! Add your number, and we’ll be able to reach you for any urgent updates or offers.",
                            fieldKey: "PhoneNumber",
                            initialValue:
                                localStorageManager.userMap['PhoneNumber']
                                    ?.toString() ??
                                '',
                            onUpdated:
                                () => setState(() {
                                  controller.phoneNumber =
                                      controller
                                          .phoneNumber; // redundant but consistent
                                  localStorageManager.userMap['PhoneNumber'] =
                                      controller.phoneNumber;
                                }),
                          ),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),

                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Obx(
                                () => Text(
                                  localStorageManager.userMap['PhoneNumber']
                                          ?.toString() ??
                                      'Enter your phone number',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.white60
                                            : Colors.black54,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: defaultSize - 10),

                    // AutoSizeText(
                    //   'Date Of Birth',
                    //   style: TextStyle(
                    //     fontSize: 22,
                    //     fontWeight: FontWeight.w500,
                    //   ),
                    // ),
                    //
                    //
                    // CommonDateWidget(
                    //   width: width,
                    //   isDarkMode: isDarkMode,
                    //   initialDate: dob,
                    //   setDate: (DateTime newDate) {
                    //     // You can store the updated date back to userMap or call a controller method
                    //     localStorageManager.userMap['DayOfBirth'] = newDate.day;
                    //     localStorageManager.userMap['MonthOfBirth'] = newDate.month;
                    //     localStorageManager.userMap['YearOfBirth'] = newDate.year;
                    //
                    //     print("Date updated: ${DateFormat('dd/MM/yyyy').format(newDate)}");
                    //   },
                    // ),
                    AutoSizeText(
                      'Date of Birth',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        controller.showDOBDialog(
                          context,
                          onUpdated:
                              () => setState(() {
                                localStorageManager.userMap['DayOfBirth'] =
                                    controller.dob?.day;
                                localStorageManager.userMap['MonthOfBirth'] =
                                    controller.dob?.month;
                                localStorageManager.userMap['YearOfBirth'] =
                                    controller.dob?.year;
                              }),
                        );
                      },
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                () {
                                  final day =
                                      localStorageManager.userMap['DayOfBirth'];
                                  final month =
                                      localStorageManager
                                          .userMap['MonthOfBirth'];
                                  final year =
                                      localStorageManager
                                          .userMap['YearOfBirth'];

                                  if (day != null &&
                                      month != null &&
                                      year != null) {
                                    final date = DateTime(year, month, day);
                                    return DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(date);
                                  }
                                  return 'Select your date of birth';
                                }(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white60
                                          : Colors.black54,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: defaultSize - 10),
                    AutoSizeText(
                      'Height (cm)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap:
                          () => controller.showEditFieldDialog(
                            context,
                            title:
                                "How tall are you, really? (No judgment, we promise!) We just need this for personalizing your experience.",
                            fieldKey: "Height",
                            initialValue: controller.heightValue,
                            onUpdated:
                                () => setState(() {
                                  // When updated, store with 2 decimal precision
                                  final height = double.tryParse(
                                    controller.heightValue.toString(),
                                  );
                                  if (height != null) {
                                    localStorageManager
                                            .userGoalDataMap['HeightData']?['Value'] =
                                        double.parse(height.toStringAsFixed(2));
                                  }
                                }),
                          ),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),

                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.heightValue.toString().isNotEmpty
                                    ? double.tryParse(
                                          controller.heightValue.toString(),
                                        )?.toStringAsFixed(2) ??
                                        'Enter your height'
                                    : 'Enter your height',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white60
                                          : Colors.black54,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: defaultSize - 10),

                    AutoSizeText(
                      'Weight (kg)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap:
                          () => controller.showEditFieldDialog(
                            context,
                            title:
                                "We know it’s a sensitive one, but it helps us tailor things to you. Don’t worry, this is just for your profile!",
                            fieldKey: "Weight",
                            initialValue: controller.weightValue,
                            onUpdated:
                                () => setState(() {
                                  controller.weightValue =
                                      controller
                                          .weightValue; // redundant but consistent
                                  localStorageManager
                                          .userMap['WeightData']?['Value'] =
                                      controller.weightValue;
                                }),
                          ),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.weightValue.toString().isNotEmpty ==
                                        true
                                    ? controller.weightValue.toString()
                                    : 'Enter your weight',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white60
                                          : Colors.black54,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: defaultSize - 10),
                    AutoSizeText(
                      'Gender',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        controller.showGenderDialog(
                          context,
                          onUpdated: () => setState(() {}),
                        );
                      },
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),

                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                localStorageManager.userMap['Gender']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true
                                    ? localStorageManager.userMap['Gender']
                                        .toString()
                                    : 'Select your gender',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white60
                                          : Colors.black54,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: defaultSize - 10),
                    AutoSizeText(
                      'Occupation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        controller.showOccupationDialog(
                          context,
                          onUpdated:
                              () => setState(() {
                                localStorageManager
                                        .userMap['OccupationData']?['Name'] =
                                    controller.occupation;
                              }),
                        );
                      },
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                localStorageManager
                                            .userMap['OccupationData']?['Name']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true
                                    ? localStorageManager
                                        .userMap['OccupationData']['Name']
                                        .toString()
                                    : 'Select your occupation',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white60
                                          : Colors.black54,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: defaultSize - 10),
                    AutoSizeText(
                      'Address',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    InkWell(
                      onTap:
                          () => controller.showEditFieldDialog(
                            context,
                            title:
                                "Enter your address — new place, new beginnings!",
                            fieldKey: "Address",
                            initialValue:
                                localStorageManager.userMap['AddressByUser']
                                    ?.toString() ??
                                '',
                            onUpdated:
                                () => setState(() {
                                  localStorageManager.userMap['AddressByUser'] =
                                      controller.address;
                                }),
                          ),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                            width: 1.2, // 👈 your border width
                          ),
                        ),

                        color: isDarkMode ? Colors.white10 : white,
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: 80, // 👈 makes box taller
                            maxHeight:
                                200, // 👈 prevents it from growing too much
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start, // 👈 align text to top
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  // 👈 allows scrolling if address is too long
                                  child: Text(
                                    localStorageManager.userMap['AddressByUser']
                                            ?.toString() ??
                                        'Enter your Address',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          isDarkMode
                                              ? Colors.white60
                                              : Colors.black54,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.edit,
                                  color: AppColors.primaryColor,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: height * 0.04),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
