import 'package:flutter/material.dart';
import 'main.dart';
import 'package:provider/provider.dart';

class NextBlock extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _NextBlockState();
}
class _NextBlockState extends State<NextBlock> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.white,
      ),
      width: double.infinity, //使用可能な最大幅
      padding: EdgeInsets.all(5.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Next',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5,), //余白
          AspectRatio(
            aspectRatio: 1, //正方形にする
            child: Container(
              color: Colors.indigo[600],
              // 次のブロックを配置する
              child: Center(
                child: Provider.of<Data>(context,listen: false).getNextBlockWidget(),
              ),
            ),
          ),
        ],
      )
    );
  }
}