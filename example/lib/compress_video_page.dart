// import 'package:flutter/material.dart';

// class CompressVideoPage extends StatefulWidget {
//   const CompressVideoPage({Key? key}) : super(key: key);

//   @override
//   _CompressVideoPageState createState() => _CompressVideoPageState();
// }

// class _CompressVideoPageState extends State<CompressVideoPage> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Compress Video'),
//       ),
//       body: Column(
//         children: [
//           Container(
//             width: double.infinity,
//             height: 200,
//             child: Column(
//               children: [
//                 Text(
//                     '当前选择: $file, 文件大小: ${fileSize != null ? (fileSize! / 1024 / 1024).toStringAsFixed(2) : 0}'),
//                 Container(
//                   width: double.infinity,
//                   height: 30,
//                 ),
//                 Text(
//                     '处理后: $outputFile, 文件大小: ${outputFileSize != null ? (outputFileSize! / 1024 / 1024).toStringAsFixed(2) : 0}'),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
