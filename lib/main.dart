import 'package:flutter/material.dart';
import 'score_bar.dart';
import 'game.dart';
import 'next_block.dart';
import 'block.dart';

import 'package:provider/provider.dart';
import 'package:flutter/services.dart';


void main() {
  runApp(
    // モデルオブジェクトに変更があると、リッスンしているWidget（配下の子Widget）を再構築する
    ChangeNotifierProvider(
      create: (context) => Data(),//モデルオブジェクトを作成する
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    // 画面をportraitモードに固定する
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return MaterialApp(home: Tetris(),);
  }
}

class Tetris extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _TetrisState();
}

// 「_」をつけるとプライベートになる
class _TetrisState extends State<Tetris> {

  // Gameエリアのウィジェットにアクセスするためグローバルキーを使う
  // ※GameStateをパブリッククラスにし、keyを受け入れるコンストラクタを作っておくこと。
  GlobalKey<GameState> _keyGame = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TETRIS'),
        centerTitle: true,
        backgroundColor: Colors.indigoAccent,
      ),
      backgroundColor: Colors.indigo,
      body: SafeArea(
        child: Column(
          children: <Widget> [
            // 全てのWidgetを一つのファイルに入れると面倒になる。
            // 必要なWidgetをでばっくで見つけることも難しくなる。
            // なので、別ファイルにクラスを宣言します。
            // ScoreBarクラスはインジケータを表示するWidgetです。
            ScoreBar(),
            Expanded(
              child: Center(
                child:Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      flex: 3,
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 10.0),
                          child: Game(key: _keyGame)//ゲームwidgetに置き換える。グローバルキーをゲームのコンストラクターに渡す。
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 10.0),
                        child:Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NextBlock(), //次のブロックを表示する枠
                            SizedBox(height: 30,), //余白
                            RaisedButton( //スタートボタン
                              child: Text(
                                //ボタンのテキストはDataモデルのisPlaying値に依存する必要がある
                                  // 廃止。グローバルキーを使って、GameStateにアクセスする
                                  // 廃止。isPlaying変数には、GameStateのcurrentStateでアクセスできる
                                  // 廃止。 _keyGame.currentState != null
                                  // 廃止。  && _keyGame.currentState.isPlaying
                                Provider.of<Data>(context, listen: false).isPlaying
                                  ? 'End': 'Start',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[200],
                                ),
                              ),
                              color: Colors.indigo[700],
                              onPressed: () {
                                // ProviderのnotifyListeners()関数で全てのWidgetが再構築されるので、
                                // setStateは不要。
                                // 廃止。Flutterにボタンを再描画させるため、setStateを使う
                                // 廃止。setState(() {
                                  //ボタン押下時の動作はDataモデルのisPlaying値に依存する必要がある
                                    // 廃止。 グローバルキーを使って、GameStateにアクセスする
                                    // 廃止。_keyGame.currentState != null
                                    // 廃止。  && _keyGame.currentState.isPlaying
                                  Provider.of<Data>(context, listen: false).isPlaying
                                    ? _keyGame.currentState.endGame()
                                    : _keyGame.currentState.startGame();
                                // 廃止。});
                              },
                            )
                          ],
                        ),

                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
    );
  }
}

// Dataモデルはwithキーワード（ミックスイン）を使ってChangeNotifier機能を拡張する
// ミックスイン: 別のクラスの機能を景勝せずに追加できる
class Data with ChangeNotifier {
  int score = 0;
  bool isPlaying = false;
  Block nextBlock;

  // スコアに任意の値を設定する（例：startGameでスコアを0に設定する）
  void setScore(score){
    this.score = score;
    notifyListeners(); // 全てのリスナーに自身を再構築するよう通知する
  }

  // ゲーム全体でスコアを累積する
  void addScore(score){
    this.score += score;
    notifyListeners(); // 全てのリスナーに自身を再構築するよう通知する
  }

  // isPlaying変数の値を変更する
  void setIsPlaying(isPlaying){
    this.isPlaying = isPlaying;
    notifyListeners(); // 全てのリスナーに自身を再構築するよう通知する
  }

  // 次のブロックをセットする
  void setNextBlock(Block nextBlock) {
    this.nextBlock = nextBlock;
    notifyListeners();
  }

  // 次のブロックを取得する
  Widget getNextBlockWidget() {
    if (!isPlaying) return Container(); //ゲームがプレイされていない時は空の透明なコンテナを返す

    // ブロックを取得するには幅、高さ、色の情報が必要
    var width = nextBlock.width;
    var height = nextBlock.height;
    var color;

    // ブロックに含まれるコンテナの総数は、幅（Columnsの数）×高さ（rowsの数）なので
    // yとxの値をループして、コンテナの行列を作成する
    List<Widget> columns = [];
    for (var y = 0; y < height; ++ y){
      List<Widget> rows = [];
      for (var x = 0; x < width; ++ x){
        // ブロックの形が見えるよう、コンテナごとに色をつける。
        // サブブロックが行列の要素と同じ座標を持つ場合
        if(nextBlock.subBlocks
            .where((subBlock) => subBlock.x == x && subBlock.y == y)
            .length >0
        ){
          color = nextBlock.color; // 次のブロックの色
        } else {
          color = Colors.transparent; //透明
        }
        // 各コンテナのサイズは 12 × 12
        rows.add(Container(width: 12, height: 12, color: color,));
      }

      // 列と行を使って全てのコンテナを結合し、水平、垂直方向に整列させる。
      columns.add(
        Row(mainAxisAlignment: MainAxisAlignment.center,children: rows));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: columns,
    );
  }

}
