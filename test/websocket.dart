import 'dart:io';

void main() async {
// 连接到WebSocket服务器
  var socket = await WebSocket.connect('wss://3hangzhou.goeasy.io/socket.io/?EIO=3&transport=websocket&b64=1');

// 发送一个消息
  socket.add('Hello, WebSocket Server!');

// 监听接收的消息
  socket.listen((data) {
    print('Received: $data');
  }, onError: (error) {
    print('Error: $error');
  }, onDone: () {
    print('Connection closed');
  });
}
