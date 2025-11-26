
import '../../consts/consts.dart';
import '../../views/Doctor/doc_book_appointment.dart';
import '../../views/Doctor/doctor_profile.dart';

class DashboardTopDoctorWidget extends StatelessWidget {
  final double width;
  DashboardTopDoctorWidget({
    super.key, required this.width,
  });

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6, // Adjust this value as needed
      child: ListView.separated(
        physics:
        PageScrollPhysics(), // Disable scrolling inside the list
        shrinkWrap: true,
        itemCount: doctors.length,

        itemBuilder: (context, index) {
          final doctor = doctors[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorProfile(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage(doctor['image']),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoSizeText(
                          doctor['name'],
                          minFontSize: 8,
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      AutoSizeText(
                          doctor['specialty'],
                        minFontSize: 8,
                          maxLines: 1,
                          maxFontSize: 18,
                          style: TextStyle(
                              fontSize: 12,
                              color: mediumGrey),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            AutoSizeText(
                              minFontSize: 8,
                              maxLines: 1,
                              maxFontSize: 14,
                              '${doctor['rating']} (${doctor['reviews']})',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8,),
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
                          SizedBox(width: 4,),
                          AutoSizeText(
                            'Fees: ₹${doctor['totalFee']}',
                            maxLines: 1,
                            minFontSize: 6,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: mediumGrey,fontSize: 8,),
                          ),

                        ],
                      ),

                      const SizedBox(height: 8),
                      Container(
                        width: width * 0.2,
                        height: width * .08,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient, // your LinearGradient
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
                          child: const AutoSizeText("Book now",
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
    );
  }
}
