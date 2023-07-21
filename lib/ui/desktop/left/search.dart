import 'package:flutter/material.dart';

class Search extends StatelessWidget {
  final Function(String val)? onSearch;

  const Search({super.key, this.onSearch});

  @override
  Widget build(BuildContext context) {
    bool changing = false;
    String value = "";
    return Container(
      height: 32,
      width: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).hoverColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        cursorHeight: 22,
        onChanged: (val) async {
          value = val;

          if (!changing) {
            changing = true;
            Future.delayed(const Duration(milliseconds: 800), () {
              changing = false;
              onSearch?.call(value);
            });
          }
        },
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(0),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
          hintText: 'Search',
          // suffixIcon: DropdownButton(
          //   value: "ALL",
          //   icon: const Icon(Icons.arrow_drop_up),
          //   isDense: true,
          //   hint: const Text('全部', style: TextStyle(fontSize: 12)),
          //   items: const [
          //     DropdownMenuItem(value: "JSON", child: Text('JSON', style: TextStyle(fontSize: 12))),
          //     DropdownMenuItem(value: "HTML", child: Text('HTML', style: TextStyle(fontSize: 12))),
          //     DropdownMenuItem(value: "ALL", child: Text('全部', style: TextStyle(fontSize: 12))),
          //   ],
          //   onChanged: (value) {},
          // ),
        ),
      ),
    );
  }
}
