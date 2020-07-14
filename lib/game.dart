import 'dart:math';
import 'package:flutter/material.dart';
import 'sub_block.dart';
import 'block.dart';
import 'dart:async';

import 'package:provider/provider.dart';
import 'main.dart';


//ブロックの衝突タイプ
enum Collision { LANDED, LANDED_BLOCK, HIT_WALL, HIT_BLOCK, NONE }

const BLOCKS_X = 10;//ゲームエリアの幅
const BLOCKS_Y = 20;//ゲームエリアの高さ
const GAME_AREA_BORDER_WIDTH = 2.0; //ゲームエリアの枠線の幅
const SUB_BLOCK_EDGE_WIDTH = 2.0; //サブブロックの枠線の幅
const REFRESH_RATE = 300; //ゲームの速度。300ミリ秒ごとに1ユニット下に移動する

class Game extends StatefulWidget {
  // GlobalKeyを受け入れるコンストラクタを作る
  // コンストラクタは受け取ったキーをその親に渡す必要がある。
  Game({Key key}): super(key: key);

  @override
  State<StatefulWidget> createState() => GameState();
}

// _GameStateはプライベートクラスなので、他のクラスからアクセスすることはできない。
// GameStateに修正する。
class GameState extends State<Game> {
  bool isGameOver = false; //ゲームオーバーフラグ
  double subBlockWidth;
  Duration duration = Duration(milliseconds: REFRESH_RATE); //期間（ゲームの速度）
  GlobalKey _keyGameArea = GlobalKey(); //秘密にしたいのでプライベート（_から始める）

  // ブロックの動き（上下左右の移動、回転）
  BlockMovement action;

  Block block;
  Timer timer;

  // Dataモデルで管理するので廃止。bool isPlaying = false; //ゲームがプレイ中かどうかを示すフラグ
  // Dataモデルで管理するので廃止。int score; //ゲームのスコア

  List<SubBlock> oldSubBlocks; //サブブロックのリスト（衝突したブロック）

  Block getNewBlock() {
    int blockType = Random().nextInt(7);
    int orientationIndex = Random().nextInt(4);

    switch (blockType) {
      case 0:
        return IBlock(orientationIndex);
      case 1:
        return JBlock(orientationIndex);
      case 2:
        return LBlock(orientationIndex);
      case 3:
        return OBlock(orientationIndex);
      case 4:
        return TBlock(orientationIndex);
      case 5:
        return SBlock(orientationIndex);
      case 6:
        return ZBlock(orientationIndex);
      default:
        return null;
    }
  }

  void startGame() {
    isGameOver = false; //ゲームオーバーフラグを初期化

    // score = 0; //スコアを初期化
    // isPlaying = true; //プレイ中フラグをONにする
    Provider.of<Data>(context, listen: false).setScore(0);
    Provider.of<Data>(context, listen: false).setIsPlaying(true);

    oldSubBlocks = List<SubBlock>(); //衝突したブロックは、Newゲームでリセットする

    //GlobalKeyを使い、ゲームエリアの現在のcontextにアクセスする
    //findRenderObjectで、レンダリングされたゲームエリアのオブジェクトを取得できる
    RenderBox renderBoxGame = _keyGameArea.currentContext.findRenderObject();

    //利用するゲームエリアは、ゲームエリアの枠線の幅を含まない
    subBlockWidth = (renderBoxGame.size.width - GAME_AREA_BORDER_WIDTH * 2) / BLOCKS_X;

    // 次のブロックを作成してDataモデルに格納
    Provider.of<Data>(context,listen: false).setNextBlock(getNewBlock());
    // 現在のブロック（ゲーム開始時の最初のブロック）
    block = getNewBlock();

    // 300ミリ秒ごとにonPlay（コールバック関数）を呼び出す
    timer = Timer.periodic(duration, onPlay);
  }

  void endGame() {
    //isPlaying = false; //プレイ中フラグをOFFにする
    Provider.of<Data>(context, listen: false).setIsPlaying(false);
    timer.cancel();
  }

  // timer引数は必須だが、別に使わなくてもいい
  void onPlay(Timer timer){
    //ブロックの衝突タイプを定義する
    var status = Collision.NONE;

    // Flutterがブロックの位置と状態が変化したことを認識するため、setStateを呼び出す
    setState(() {
      // ユーザー入力であるアクションを実行する
      if (action != null) {
        // 壁に当たっていない限り、ブロックを動かせる
        if(!checkOnEdge(action)){
          block.move(action);
        }
      }

      // もし古いブロックに当たったら、ブロックを逆に動かしてキャンセルする
      for (var oldSubBlock in oldSubBlocks) {
        for (var subBlock in block.subBlocks) {
          // 絶対座標にする
          var x = block.x + subBlock.x;
          var y = block.y + subBlock.y;
          // もし古いサブブロックと重なっていたら（x座標とy座標が等しかったら）
          if(x == oldSubBlock.x && y == oldSubBlock.y) {
            // 逆に動かして移動をキャンセルする
            switch (action){
              // ユーザーが左に動かしていたら右に動かす（＝左移動キャンセル）
              case BlockMovement.LEFT:
                block.move(BlockMovement.RIGHT);
                break;
              // ユーザーが右に動かしていたら左に動かす（＝右移動キャンセル）
              case BlockMovement.RIGHT:
                block.move(BlockMovement.LEFT);
                break;
              // ユーザーが回転させたら、反時計回りに回転する（＝回転キャンセル）
              case BlockMovement.ROTATE_CLOCKWISE:
                block.move(BlockMovement.ROTATE_COUNTER_CLOCKWISE);
                break;
              default:
                break;
            }
          }
        }

      }

      //ブロックが床に衝突したかチェックする
      if (!checkAtBottom()) {
        // ブロックが古いサブブロックに着いたかチェックする
        if (!checkAboveBlock()) {
          block.move(BlockMovement.DOWN);
        } else {
          status = Collision.LANDED_BLOCK;
        }
      } else {
        status = Collision.LANDED;
      }

      // y座標がマイナス（ゲームエリアのTOPを超えた）でゲームオーバー
      if (status == Collision.LANDED_BLOCK && block.y < 0){
        isGameOver = true;
        endGame();
      }

      //ブロックが床に着いた、もしくは、古いサブブロックに着いたら、次のブロックを落とす
      if(status == Collision.LANDED || status == Collision.LANDED_BLOCK) {
        // 衝突したブロックをサブブロックとしてoldSubBlockに追加する。
        block.subBlocks.forEach((subBlock) {
          // 相対座標から絶対座標に変換する
          subBlock.x += block.x;
          subBlock.y += block.y;
          oldSubBlocks.add(subBlock);
        });

        // 廃止。block = getNewBlock();
        // ブロックは次のブロック（Dataモデル）から取得する
        block = Provider.of<Data>(context, listen: false).nextBlock;
        // 次のブロックを作成し、Dataモデルにセットする
        Provider.of<Data>(context, listen: false).setNextBlock(getNewBlock());
      }

      // ブロックに対するユーザーからの入力を初期化する
      action = null;
      updateScore();
    });
  }

  // スコアリング
  void updateScore(){
    var combo = 1; // コンボ数（同時に消した行数）を変数宣言する
    Map<int, int> rows = Map(); //消すy座標と、消すサブブロックの数（＝点数）のマップ
    List<int> rowsToBeRemoved = List(); //消す行のy座標のリスト

    // サブブロックがあったら、行ごとにy座標とサブブロックの数をマッピングする
    oldSubBlocks?.forEach((subBlock) {
      //サブブロックのy座標をマップにセット
      rows.update(subBlock.y,
              //そのy座標にあるサブブロックの数をカウントしてマップにセット（ない場合は1）
              (value) => ++ value, ifAbsent: () => 1);
    });
    //もし一行揃っていたら、スコアに加える
    rows.forEach((rowNum, count) {
      // y座標に含まれるサブブロックの数が、行サイズと同じ場合（一行揃ってる場合）
      if (count == BLOCKS_X){
        // score += combo++; //コンボを1増やす
        // print('score: $score');
        Provider.of<Data>(context, listen: false).addScore(combo++);

        rowsToBeRemoved.add(rowNum); //y座標を消す行のリストに入れる
      }
    });

    // 揃った行のサブブロックを消す
    if(rowsToBeRemoved.length > 0) {
      removeRows(rowsToBeRemoved);
    }
  }

  // サブブロックを消す
  void removeRows(List<int> rowsToBeRemoved) {
    rowsToBeRemoved.sort(); //並べ替える
    //上に表示されているブロックから（y座標が小さい順に）消していく
    rowsToBeRemoved.forEach((rowNum){
      //y座標が一致するサブブロックを消す
      oldSubBlocks.removeWhere((subBlock) => subBlock.y == rowNum);
      //消した一行分、他のサブブロックを一行ずつ下に移動させて表示させる（y座標の値に1を足す）
      oldSubBlocks.forEach((subBlock) {
        if(subBlock.y < rowNum) {
          ++subBlock.y;
        }
      });
    });
  }

  // ブロックが床にあるかをチェックする
  bool checkAtBottom() {
    return block.y + block.height == BLOCKS_Y;
  }

  // ブロックが古いサブブロックの上にあるかをチェックする
  bool checkAboveBlock() {
    // 今ある古いサブブロックをループして、新しいブロックが上に着いたことをチェックする
    for (var oldSubBlock in oldSubBlocks) {
      for (var subBlock in block.subBlocks) {
        var x = block.x + subBlock.x;
        var y = block.y + subBlock.y;
        if (x == oldSubBlock.x && y + 1 == oldSubBlock.y){
          return true;
        }
      }
    }
    return false;
  }

  // ブロックが壁をはみ出したことをチェックする
  bool checkOnEdge(BlockMovement action){
    // 左に動かしてx座標がマイナス、または、
    return (action == BlockMovement.LEFT && block.x <= 0) ||
        // 右に動かした時のブロックの右端が、ゲームエリアの幅を超えていない時、trueを返す
        (action == BlockMovement.RIGHT && block.x + block.width >= BLOCKS_X);
  }


  // 配置されたコンテナを作成する関数
  Widget getPositionedSquareContainer(Color color, int x, int y){
    return Positioned(
      // ピクセル座標（絶対座標）
      left: x * subBlockWidth,
      top: y * subBlockWidth,
      child: Container(
        width: subBlockWidth - SUB_BLOCK_EDGE_WIDTH, //サブブロック同士がくっついて見えないようにする
        height: subBlockWidth - SUB_BLOCK_EDGE_WIDTH,
        decoration: BoxDecoration(
          color: color,
          // BorderまたはBoxDecotationを描画するときに使う形状。circle（円）とrectangle（長方形）が選べる。
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.all(const Radius.circular(3.0)),
        ),
      ),
    );
  }

  // ブロックを描画する
  Widget drawBlocks(){
    // 初期化
    if (block == null) return null;
    // サブブロックは、配置可能なWidgetのリストとして宣言する
    List<Positioned> subBlocks = List();

    // 新しいブロックを作る＝各サブブロックをループし、それぞれをコンテナに変換する
    block.subBlocks.forEach((subBlock){
      subBlocks.add(getPositionedSquareContainer(
        //絶対座標にする（サブブロックの座標はブロックの相対位置なのでそれぞれ足す）
          subBlock.color, subBlock.x + block.x, subBlock.y + block.y));
    });

    // 古いブロック（サブブロックのリスト）を描画する
    oldSubBlocks?.forEach((oldSubBlock) {
      subBlocks.add(getPositionedSquareContainer(
          oldSubBlock.color, oldSubBlock.x, oldSubBlock.y));
    });

    if (isGameOver) {
      subBlocks.add(getGameOvertRect());
    }

    return Stack(children: subBlocks,);
  }

  // ゲームオーバーブロックを描画する
  Widget getGameOvertRect(){
    return Positioned( //配置可能なコンテナ
      child: Container(
        // ゲームオーバーブロックは大きいサイズにする
        width: subBlockWidth * 8.0,
        height: subBlockWidth * 3.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.all(Radius.circular(10.0))
        ),
        child: Text('Game Over',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      // ゲームオーバーブロックを配置するポジションを指定
      left: subBlockWidth * 1.0,
      top: subBlockWidth * 6.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(//ゲームエリアをコントロールパネルにする
      // ブロックを水平方向に移動させる（ドラッグを検出する）
      onHorizontalDragUpdate: (details){
        if (details.delta.dx > 0) {
          action = BlockMovement.RIGHT;
        } else {
          action = BlockMovement.LEFT;
        }
      },
      // ブロックを回転させる
      onTap: (){
        action = BlockMovement.ROTATE_CLOCKWISE;
      },

      child:AspectRatio(
        aspectRatio: BLOCKS_X / BLOCKS_Y, //高さに対する幅の比率
        child: Container(
          key: _keyGameArea, //ゲームエリアのグローバルキー
          decoration: BoxDecoration(
            color: Colors.indigo[800],
            border: Border.all(
              width: GAME_AREA_BORDER_WIDTH,
              color: Colors.indigoAccent
            ),
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
          ),
          child: drawBlocks(), // ブロックを描画する
        ),
      ),
    );
  }
}