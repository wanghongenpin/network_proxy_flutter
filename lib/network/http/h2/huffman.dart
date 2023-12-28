import 'dart:typed_data';

main() {
  var list = [241, 227, 194, 254, 231, 52, 246, 174, 67, 211];
  print(HuffmanDecoder().decode(list));
}
class HuffmanDecoder {
  static const int eosByte = 256; //end of string

  final HuffmanTreeNode _root;

  HuffmanDecoder() : _root = generateHuffmanTree(_huffmanTable);

  //http2协议规范 huffman解码
  List<int> decode(List<int> bytes) {
    var buffer = BytesBuilder();

    var currentByteOffset = 0;
    var node = _root;
    var currentDepth = 0;
    while (currentByteOffset < bytes.length) {
      var byte = bytes[currentByteOffset];
      for (var currentBit = 7; currentBit >= 0; currentBit--) {
        var right = (byte >> currentBit) & 1 == 1;
        if (right) {
          node = node.right!;
        } else {
          node = node.left!;
        }
        currentDepth++;
        if (node.value != null) {
          if (node.value == eosByte) {
            throw Exception('More than 7 bit padding is not allowed. Found entire EOS '
                'encoding');
          }
          buffer.addByte(node.value!);
          node = _root;
          currentDepth = 0;
        }
      }
      currentByteOffset++;
    }

    if (node != _root) {
      if (currentDepth > 7) {
        throw Exception('Incomplete encoding of a byte or more than 7 bit padding.');
      }

      while (node.right != null) {
        node = node.right!;
      }

      if (node.value != 256) {
        throw Exception('Incomplete encoding of a byte.');
      }
    }

    return buffer.takeBytes();
  }
}

class HuffmanEncoder {
  static const int eosByte = 256; //end of string

  final List<EncodedHuffmanValue> _codewords;

  HuffmanEncoder() : _codewords = _huffmanTable;

  //http2协议规范 huffman编码
  List<int> encode(List<int> bytes) {
    var buffer = BytesBuilder();

    var currentByte = 0;
    var currentBitOffset = 7;

    void writeValue(int value, int numBits) {
      var i = numBits - 1;
      while (i >= 0) {
        if (currentBitOffset == 7 && i >= 7) {
          assert(currentByte == 0);

          buffer.addByte((value >> (i - 7)) & 0xff);
          currentBitOffset = 7;
          currentByte = 0;
          i -= 8;
        } else {
          currentByte |= ((value >> i) & 1) << currentBitOffset;

          currentBitOffset--;
          if (currentBitOffset == -1) {
            buffer.addByte(currentByte);
            currentBitOffset = 7;
            currentByte = 0;
          }
          i--;
        }
      }
    }

    for (var i = 0; i < bytes.length; i++) {
      var byte = bytes[i];
      var value = _codewords[byte];
      writeValue(value.encodedBytes, value.numBits);
    }

    if (currentBitOffset < 7) {
      writeValue(0xff, 1 + currentBitOffset);
    }

    return buffer.takeBytes();
  }

}
///生成h2 huffman解码tree
HuffmanTreeNode generateHuffmanTree(List<EncodedHuffmanValue> valueEncodings) {
  var root = HuffmanTreeNode();

  for (var byteOffset = 0; byteOffset < valueEncodings.length; byteOffset++) {
    var entry = valueEncodings[byteOffset];

    var current = root;
    for (var bitNr = 0; bitNr < entry.numBits; bitNr++) {
      var right = ((entry.encodedBytes >> (entry.numBits - bitNr - 1)) & 1) == 1;

      if (right) {
        current.right ??= HuffmanTreeNode();
        current = current.right!;
      } else {
        current.left ??= HuffmanTreeNode();
        current = current.left!;
      }
    }

    current.value = byteOffset;
  }

  return root;
}

class HuffmanTreeNode {
  int? value;

  HuffmanTreeNode? left;
  HuffmanTreeNode? right;

  bool isLeaf() {
    return left == null && right == null;
  }
}

//HPACK规范 huffman编码的字节编码列表。
final List<EncodedHuffmanValue> _huffmanTable = [
  EncodedHuffmanValue(0x1ff8, 13),
  EncodedHuffmanValue(0x7fffd8, 23),
  EncodedHuffmanValue(0xfffffe2, 28),
  EncodedHuffmanValue(0xfffffe3, 28),
  EncodedHuffmanValue(0xfffffe4, 28),
  EncodedHuffmanValue(0xfffffe5, 28),
  EncodedHuffmanValue(0xfffffe6, 28),
  EncodedHuffmanValue(0xfffffe7, 28),
  EncodedHuffmanValue(0xfffffe8, 28),
  EncodedHuffmanValue(0xffffea, 24),
  EncodedHuffmanValue(0x3ffffffc, 30),
  EncodedHuffmanValue(0xfffffe9, 28),
  EncodedHuffmanValue(0xfffffea, 28),
  EncodedHuffmanValue(0x3ffffffd, 30),
  EncodedHuffmanValue(0xfffffeb, 28),
  EncodedHuffmanValue(0xfffffec, 28),
  EncodedHuffmanValue(0xfffffed, 28),
  EncodedHuffmanValue(0xfffffee, 28),
  EncodedHuffmanValue(0xfffffef, 28),
  EncodedHuffmanValue(0xffffff0, 28),
  EncodedHuffmanValue(0xffffff1, 28),
  EncodedHuffmanValue(0xffffff2, 28),
  EncodedHuffmanValue(0x3ffffffe, 30),
  EncodedHuffmanValue(0xffffff3, 28),
  EncodedHuffmanValue(0xffffff4, 28),
  EncodedHuffmanValue(0xffffff5, 28),
  EncodedHuffmanValue(0xffffff6, 28),
  EncodedHuffmanValue(0xffffff7, 28),
  EncodedHuffmanValue(0xffffff8, 28),
  EncodedHuffmanValue(0xffffff9, 28),
  EncodedHuffmanValue(0xffffffa, 28),
  EncodedHuffmanValue(0xffffffb, 28),
  EncodedHuffmanValue(0x14, 6),
  EncodedHuffmanValue(0x3f8, 10),
  EncodedHuffmanValue(0x3f9, 10),
  EncodedHuffmanValue(0xffa, 12),
  EncodedHuffmanValue(0x1ff9, 13),
  EncodedHuffmanValue(0x15, 6),
  EncodedHuffmanValue(0xf8, 8),
  EncodedHuffmanValue(0x7fa, 11),
  EncodedHuffmanValue(0x3fa, 10),
  EncodedHuffmanValue(0x3fb, 10),
  EncodedHuffmanValue(0xf9, 8),
  EncodedHuffmanValue(0x7fb, 11),
  EncodedHuffmanValue(0xfa, 8),
  EncodedHuffmanValue(0x16, 6),
  EncodedHuffmanValue(0x17, 6),
  EncodedHuffmanValue(0x18, 6),
  EncodedHuffmanValue(0x0, 5),
  EncodedHuffmanValue(0x1, 5),
  EncodedHuffmanValue(0x2, 5),
  EncodedHuffmanValue(0x19, 6),
  EncodedHuffmanValue(0x1a, 6),
  EncodedHuffmanValue(0x1b, 6),
  EncodedHuffmanValue(0x1c, 6),
  EncodedHuffmanValue(0x1d, 6),
  EncodedHuffmanValue(0x1e, 6),
  EncodedHuffmanValue(0x1f, 6),
  EncodedHuffmanValue(0x5c, 7),
  EncodedHuffmanValue(0xfb, 8),
  EncodedHuffmanValue(0x7ffc, 15),
  EncodedHuffmanValue(0x20, 6),
  EncodedHuffmanValue(0xffb, 12),
  EncodedHuffmanValue(0x3fc, 10),
  EncodedHuffmanValue(0x1ffa, 13),
  EncodedHuffmanValue(0x21, 6),
  EncodedHuffmanValue(0x5d, 7),
  EncodedHuffmanValue(0x5e, 7),
  EncodedHuffmanValue(0x5f, 7),
  EncodedHuffmanValue(0x60, 7),
  EncodedHuffmanValue(0x61, 7),
  EncodedHuffmanValue(0x62, 7),
  EncodedHuffmanValue(0x63, 7),
  EncodedHuffmanValue(0x64, 7),
  EncodedHuffmanValue(0x65, 7),
  EncodedHuffmanValue(0x66, 7),
  EncodedHuffmanValue(0x67, 7),
  EncodedHuffmanValue(0x68, 7),
  EncodedHuffmanValue(0x69, 7),
  EncodedHuffmanValue(0x6a, 7),
  EncodedHuffmanValue(0x6b, 7),
  EncodedHuffmanValue(0x6c, 7),
  EncodedHuffmanValue(0x6d, 7),
  EncodedHuffmanValue(0x6e, 7),
  EncodedHuffmanValue(0x6f, 7),
  EncodedHuffmanValue(0x70, 7),
  EncodedHuffmanValue(0x71, 7),
  EncodedHuffmanValue(0x72, 7),
  EncodedHuffmanValue(0xfc, 8),
  EncodedHuffmanValue(0x73, 7),
  EncodedHuffmanValue(0xfd, 8),
  EncodedHuffmanValue(0x1ffb, 13),
  EncodedHuffmanValue(0x7fff0, 19),
  EncodedHuffmanValue(0x1ffc, 13),
  EncodedHuffmanValue(0x3ffc, 14),
  EncodedHuffmanValue(0x22, 6),
  EncodedHuffmanValue(0x7ffd, 15),
  EncodedHuffmanValue(0x3, 5),
  EncodedHuffmanValue(0x23, 6),
  EncodedHuffmanValue(0x4, 5),
  EncodedHuffmanValue(0x24, 6),
  EncodedHuffmanValue(0x5, 5),
  EncodedHuffmanValue(0x25, 6),
  EncodedHuffmanValue(0x26, 6),
  EncodedHuffmanValue(0x27, 6),
  EncodedHuffmanValue(0x6, 5),
  EncodedHuffmanValue(0x74, 7),
  EncodedHuffmanValue(0x75, 7),
  EncodedHuffmanValue(0x28, 6),
  EncodedHuffmanValue(0x29, 6),
  EncodedHuffmanValue(0x2a, 6),
  EncodedHuffmanValue(0x7, 5),
  EncodedHuffmanValue(0x2b, 6),
  EncodedHuffmanValue(0x76, 7),
  EncodedHuffmanValue(0x2c, 6),
  EncodedHuffmanValue(0x8, 5),
  EncodedHuffmanValue(0x9, 5),
  EncodedHuffmanValue(0x2d, 6),
  EncodedHuffmanValue(0x77, 7),
  EncodedHuffmanValue(0x78, 7),
  EncodedHuffmanValue(0x79, 7),
  EncodedHuffmanValue(0x7a, 7),
  EncodedHuffmanValue(0x7b, 7),
  EncodedHuffmanValue(0x7ffe, 15),
  EncodedHuffmanValue(0x7fc, 11),
  EncodedHuffmanValue(0x3ffd, 14),
  EncodedHuffmanValue(0x1ffd, 13),
  EncodedHuffmanValue(0xffffffc, 28),
  EncodedHuffmanValue(0xfffe6, 20),
  EncodedHuffmanValue(0x3fffd2, 22),
  EncodedHuffmanValue(0xfffe7, 20),
  EncodedHuffmanValue(0xfffe8, 20),
  EncodedHuffmanValue(0x3fffd3, 22),
  EncodedHuffmanValue(0x3fffd4, 22),
  EncodedHuffmanValue(0x3fffd5, 22),
  EncodedHuffmanValue(0x7fffd9, 23),
  EncodedHuffmanValue(0x3fffd6, 22),
  EncodedHuffmanValue(0x7fffda, 23),
  EncodedHuffmanValue(0x7fffdb, 23),
  EncodedHuffmanValue(0x7fffdc, 23),
  EncodedHuffmanValue(0x7fffdd, 23),
  EncodedHuffmanValue(0x7fffde, 23),
  EncodedHuffmanValue(0xffffeb, 24),
  EncodedHuffmanValue(0x7fffdf, 23),
  EncodedHuffmanValue(0xffffec, 24),
  EncodedHuffmanValue(0xffffed, 24),
  EncodedHuffmanValue(0x3fffd7, 22),
  EncodedHuffmanValue(0x7fffe0, 23),
  EncodedHuffmanValue(0xffffee, 24),
  EncodedHuffmanValue(0x7fffe1, 23),
  EncodedHuffmanValue(0x7fffe2, 23),
  EncodedHuffmanValue(0x7fffe3, 23),
  EncodedHuffmanValue(0x7fffe4, 23),
  EncodedHuffmanValue(0x1fffdc, 21),
  EncodedHuffmanValue(0x3fffd8, 22),
  EncodedHuffmanValue(0x7fffe5, 23),
  EncodedHuffmanValue(0x3fffd9, 22),
  EncodedHuffmanValue(0x7fffe6, 23),
  EncodedHuffmanValue(0x7fffe7, 23),
  EncodedHuffmanValue(0xffffef, 24),
  EncodedHuffmanValue(0x3fffda, 22),
  EncodedHuffmanValue(0x1fffdd, 21),
  EncodedHuffmanValue(0xfffe9, 20),
  EncodedHuffmanValue(0x3fffdb, 22),
  EncodedHuffmanValue(0x3fffdc, 22),
  EncodedHuffmanValue(0x7fffe8, 23),
  EncodedHuffmanValue(0x7fffe9, 23),
  EncodedHuffmanValue(0x1fffde, 21),
  EncodedHuffmanValue(0x7fffea, 23),
  EncodedHuffmanValue(0x3fffdd, 22),
  EncodedHuffmanValue(0x3fffde, 22),
  EncodedHuffmanValue(0xfffff0, 24),
  EncodedHuffmanValue(0x1fffdf, 21),
  EncodedHuffmanValue(0x3fffdf, 22),
  EncodedHuffmanValue(0x7fffeb, 23),
  EncodedHuffmanValue(0x7fffec, 23),
  EncodedHuffmanValue(0x1fffe0, 21),
  EncodedHuffmanValue(0x1fffe1, 21),
  EncodedHuffmanValue(0x3fffe0, 22),
  EncodedHuffmanValue(0x1fffe2, 21),
  EncodedHuffmanValue(0x7fffed, 23),
  EncodedHuffmanValue(0x3fffe1, 22),
  EncodedHuffmanValue(0x7fffee, 23),
  EncodedHuffmanValue(0x7fffef, 23),
  EncodedHuffmanValue(0xfffea, 20),
  EncodedHuffmanValue(0x3fffe2, 22),
  EncodedHuffmanValue(0x3fffe3, 22),
  EncodedHuffmanValue(0x3fffe4, 22),
  EncodedHuffmanValue(0x7ffff0, 23),
  EncodedHuffmanValue(0x3fffe5, 22),
  EncodedHuffmanValue(0x3fffe6, 22),
  EncodedHuffmanValue(0x7ffff1, 23),
  EncodedHuffmanValue(0x3ffffe0, 26),
  EncodedHuffmanValue(0x3ffffe1, 26),
  EncodedHuffmanValue(0xfffeb, 20),
  EncodedHuffmanValue(0x7fff1, 19),
  EncodedHuffmanValue(0x3fffe7, 22),
  EncodedHuffmanValue(0x7ffff2, 23),
  EncodedHuffmanValue(0x3fffe8, 22),
  EncodedHuffmanValue(0x1ffffec, 25),
  EncodedHuffmanValue(0x3ffffe2, 26),
  EncodedHuffmanValue(0x3ffffe3, 26),
  EncodedHuffmanValue(0x3ffffe4, 26),
  EncodedHuffmanValue(0x7ffffde, 27),
  EncodedHuffmanValue(0x7ffffdf, 27),
  EncodedHuffmanValue(0x3ffffe5, 26),
  EncodedHuffmanValue(0xfffff1, 24),
  EncodedHuffmanValue(0x1ffffed, 25),
  EncodedHuffmanValue(0x7fff2, 19),
  EncodedHuffmanValue(0x1fffe3, 21),
  EncodedHuffmanValue(0x3ffffe6, 26),
  EncodedHuffmanValue(0x7ffffe0, 27),
  EncodedHuffmanValue(0x7ffffe1, 27),
  EncodedHuffmanValue(0x3ffffe7, 26),
  EncodedHuffmanValue(0x7ffffe2, 27),
  EncodedHuffmanValue(0xfffff2, 24),
  EncodedHuffmanValue(0x1fffe4, 21),
  EncodedHuffmanValue(0x1fffe5, 21),
  EncodedHuffmanValue(0x3ffffe8, 26),
  EncodedHuffmanValue(0x3ffffe9, 26),
  EncodedHuffmanValue(0xffffffd, 28),
  EncodedHuffmanValue(0x7ffffe3, 27),
  EncodedHuffmanValue(0x7ffffe4, 27),
  EncodedHuffmanValue(0x7ffffe5, 27),
  EncodedHuffmanValue(0xfffec, 20),
  EncodedHuffmanValue(0xfffff3, 24),
  EncodedHuffmanValue(0xfffed, 20),
  EncodedHuffmanValue(0x1fffe6, 21),
  EncodedHuffmanValue(0x3fffe9, 22),
  EncodedHuffmanValue(0x1fffe7, 21),
  EncodedHuffmanValue(0x1fffe8, 21),
  EncodedHuffmanValue(0x7ffff3, 23),
  EncodedHuffmanValue(0x3fffea, 22),
  EncodedHuffmanValue(0x3fffeb, 22),
  EncodedHuffmanValue(0x1ffffee, 25),
  EncodedHuffmanValue(0x1ffffef, 25),
  EncodedHuffmanValue(0xfffff4, 24),
  EncodedHuffmanValue(0xfffff5, 24),
  EncodedHuffmanValue(0x3ffffea, 26),
  EncodedHuffmanValue(0x7ffff4, 23),
  EncodedHuffmanValue(0x3ffffeb, 26),
  EncodedHuffmanValue(0x7ffffe6, 27),
  EncodedHuffmanValue(0x3ffffec, 26),
  EncodedHuffmanValue(0x3ffffed, 26),
  EncodedHuffmanValue(0x7ffffe7, 27),
  EncodedHuffmanValue(0x7ffffe8, 27),
  EncodedHuffmanValue(0x7ffffe9, 27),
  EncodedHuffmanValue(0x7ffffea, 27),
  EncodedHuffmanValue(0x7ffffeb, 27),
  EncodedHuffmanValue(0xffffffe, 28),
  EncodedHuffmanValue(0x7ffffec, 27),
  EncodedHuffmanValue(0x7ffffed, 27),
  EncodedHuffmanValue(0x7ffffee, 27),
  EncodedHuffmanValue(0x7ffffef, 27),
  EncodedHuffmanValue(0x7fffff0, 27),
  EncodedHuffmanValue(0x3ffffee, 26),
  EncodedHuffmanValue(0x3fffffff, 30),
];

class EncodedHuffmanValue {
  final int encodedBytes;
  final int numBits;

  EncodedHuffmanValue(this.encodedBytes, this.numBits);
}
