import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Chat/dr_chat.dart';

void main() => runApp(MaterialApp(home: DoctorsChatHistory()));

class DoctorsChatHistory extends StatelessWidget {
  final List<Map<String, dynamic>> chatData = [
    {
      "name": "Dr. Sharma",
      "message": "Great to hear that.",
      "time": "10:41 am",
      "image": avatar1,
    },
    {
      "name": "Charlis Winns",
      "message": "Direct message through cdr",
      "time": "10:41 am",
      "image": avatar2,
    },
    {
      "name": "Tean Aim",
      "message": "Great to hear that.",
      "time": "10:41 am",
      "image": avatar3,
    },
    {
      "name": "Tewelve Ancy",
      "message": "Thanks yeager",
      "time": "10:41 am",
      "image": avatar4,
    },
    {
      "name": "Milton Edward",
      "message": "Great to hear that.",
      "time": "10:41 am",
      "image": avatar5,
    },
    {
      "name": "Dr. Sharma",
      "message": "Feed bone to your dog",
      "time": "10:41 am",
      "image": avatar6,
    },
    {
      "name": "Adshish Kumar",
      "message": "Nutrition chart is send to you....",
      "time": "10:41 am",
      "image": avatar7,
    },
    {
      "name": "Dr. Sharma",
      "message": "Feed bone to your dog",
      "time": "10:41 am",
      "image": avatar6,
    },
    {
      "name": "Adshish Kumar",
      "message": "Nutrition chart is send to you....",
      "time": "10:41 am",
      "image": avatar7,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    //  final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: SafeArea(
          child: Row(
            children: [
              Material(
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
              const SizedBox(width: 10),
              SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.primaryColor,
                      ),
                      hintText: 'Search people',
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [_buildTabBar(), Expanded(child: _buildChatList())],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildTab("All", selected: true),
          _buildTab("Recent"),
          _buildTab("Active Now"),
        ],
      ),
    );
  }

  Widget _buildTab(String label, {bool selected = false}) {
    return Container(
      margin: EdgeInsets.only(right: 20),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color:
            selected
                ? AppColors.primaryColor.withOpacity(0.2)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: selected ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primaryColor,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.separated(
      itemCount: chatData.length,
      separatorBuilder:
          (_, _) => Divider(indent: 20, thickness: 1, endIndent: 20),
      itemBuilder: (context, index) {
        final data = chatData[index];
        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DrChat()),
            );
          },
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: AssetImage(data['image']),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(backgroundColor: Colors.green, radius: 5),
              ),
            ],
          ),
          title: Text(
            data["name"]!,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(data["message"]!, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(data["time"]!, style: TextStyle(fontSize: 12)),
              SizedBox(height: 4),
              CircleAvatar(radius: 4, backgroundColor: Colors.red),
            ],
          ),
        );
      },
    );
  }
}
