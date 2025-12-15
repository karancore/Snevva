import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Doctor/doc_book_appointment.dart';
import 'package:snevva/views/Doctor/doctor_profile.dart';

class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> doctors = [
    {
      'name': 'Dr. Eion Morgan',
      'specialty': 'Neuromedicine',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc1,
    },
    {
      'name': 'Dr. Jerry Jones',
      'specialty': 'Neurolist',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc2,
    },
    {
      'name': 'Dr. Eion Morgan',
      'specialty': 'Neuromedicine',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc3,
    },
    {
      'name': 'Dr. Jerry Jones',
      'specialty': 'Neurolist',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc1,
    },
    {
      'name': 'Dr. Jerry Jones',
      'specialty': 'Neurolist',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc2,
    },
    {
      'name': 'Dr. Eion Morgan',
      'specialty': 'Neuromedicine',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc3,
    },
    {
      'name': 'Dr. Jerry Jones',
      'specialty': 'Neurolist',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc1,
    },
    {
      'name': 'Dr. Jerry Jones',
      'specialty': 'Neurolist',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc2,
    },
    {
      'name': 'Dr. Eion Morgan',
      'specialty': 'Neuromedicine',
      'rating': 4.5,
      'reviews': 4435,
      'fee': 500,
      'totalFee': 750,
      'image': doc3,
    },
  ];
  late AnimationController listAnimationController;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    listAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _slideAnimations = List.generate(doctors.length, (index) {
      final start = index * (1.0 / doctors.length);
      final end = start + 0.5;
      return Tween<Offset>(begin: Offset(-1, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: listAnimationController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });
    listAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: SafeArea(
              child: Row(
                children: [
                  Transform.translate(
                    offset: Offset(-8, 0),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 0,
                      child: Builder(
                        builder: (context) {
                          return IconButton(
                            icon: SvgPicture.asset(drawerIcon),
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      elevation: 1,
                      color:
                          isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                      borderRadius: BorderRadius.circular(4),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: const Icon(Icons.filter_list),
                          hintText: 'Search Available Settings',
                          hintStyle: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Optional: Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCustomChip(
                    "Neurologist",
                    Colors.green.shade100,
                    Colors.green,
                  ),
                  _buildCustomChip(
                    "Neuromedicine",
                    Colors.orange.shade100,
                    Colors.orange,
                  ),
                  _buildCustomChip(
                    "Dermatologist",
                    Colors.blue.shade100,
                    Colors.blue,
                  ),
                  _buildCustomChip(
                    "Pediatrician",
                    Colors.red.shade100,
                    Colors.red,
                  ),
                  _buildCustomChip(
                    "Psychiatrist",
                    Colors.yellow.shade100,
                    Colors.amber,
                  ),
                  _buildCustomChip(
                    "Rheumatologist",
                    Colors.cyan.shade100,
                    Colors.cyan,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DoctorProfile()),
                );
              },
              child: ListView.separated(
                itemCount: doctors.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return SlideTransition(
                    position: _slideAnimations[index],
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage(doctor['image']),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  doctor['specialty'],
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${doctor['rating']} (${doctor['reviews']})',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  AutoSizeText(
                                    '₹${doctor['fee']}',
                                    maxLines: 1,
                                    minFontSize: 8,
                                    style: const TextStyle(color: green),
                                  ),
                                  SizedBox(width: 4),
                                  AutoSizeText(
                                    'Fees: ₹${doctor['totalFee']}',
                                    maxLines: 1,
                                    minFontSize: 6,
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: mediumGrey,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),
                              Container(
                                width: width * 0.2,
                                height: width * .08,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  // your LinearGradient
                                  borderRadius: BorderRadius.circular(
                                    4,
                                  ), // more roundness
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DocBookAppointment(),
                                      ),
                                    );
                                  },
                                  child: const AutoSizeText(
                                    "Book now",
                                    minFontSize: 8,
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return Divider(
                    color: mediumGrey,
                    thickness: 0.5,
                    indent: 4,
                    endIndent: 4,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomChip(String label, Color bgColor, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: TextStyle(color: black)),
        backgroundColor: bgColor,
        deleteIcon: Icon(Icons.close, size: 16, color: iconColor),
        onDeleted: () {
          // Handle remove logic here
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
