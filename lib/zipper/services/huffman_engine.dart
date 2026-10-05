import 'package:archive/archive.dart';

import 'dart:typed_data';

/// Node for the Huffman Binary Tree
class HuffmanNode implements Comparable<HuffmanNode> {
  final int? byteValue;
  final int frequency;
  HuffmanNode? left;
  HuffmanNode? right;

  HuffmanNode({this.byteValue, required this.frequency, this.left, this.right});

  bool get isLeaf => left == null && right == null;

  @override
  int compareTo(HuffmanNode other) {
    return frequency.compareTo(other.frequency);
  }
}

/// Custom Min-Heap (Priority Queue) Implementation
class MinHeap<T extends Comparable<T>> {
  final List<T> _heap = [];

  int get length => _heap.length;
  bool get isEmpty => _heap.isEmpty;

  void insert(T value) {
    _heap.add(value);
    _siftUp(_heap.length - 1);
  }

  T extractMin() {
    if (isEmpty) throw StateError("Heap is empty");
    final minVal = _heap[0];
    final lastVal = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = lastVal;
      _siftDown(0);
    }
    return minVal;
  }

  void _siftUp(int index) {
    while (index > 0) {
      int parent = (index - 1) ~/ 2;
      if (_heap[index].compareTo(_heap[parent]) < 0) {
        _swap(index, parent);
        index = parent;
      } else {
        break;
      }
    }
  }

  void _siftDown(int index) {
    int size = _heap.length;
    while (true) {
      int left = 2 * index + 1;
      int right = 2 * index + 2;
      int smallest = index;

      if (left < size && _heap[left].compareTo(_heap[smallest]) < 0) {
        smallest = left;
      }
      if (right < size && _heap[right].compareTo(_heap[smallest]) < 0) {
        smallest = right;
      }

      if (smallest != index) {
        _swap(index, smallest);
        index = smallest;
      } else {
        break;
      }
    }
  }

  void _swap(int first, int second) {
    final value = _heap[first];
    _heap[first] = _heap[second];
    _heap[second] = value;
  }
}

class HuffmanEngine {
  static const List<int> magicHeader = [0x48, 0x55, 0x46, 0x46]; // "HUFF"

  static Uint8List compress(Uint8List inputData) {
    if (inputData.isEmpty) {
      final builder = BytesBuilder();
      builder.add(magicHeader);
      builder.add(_int64ToBytes(0));
      builder.add(_int16ToBytes(0));
      return builder.toBytes();
    }

    // 1. Frequency Table
    final freqMap = List<int>.filled(256, 0);
    for (var byte in inputData) {
      freqMap[byte]++;
    }

    // 2. Build Min-Heap
    final heap = MinHeap<HuffmanNode>();
    for (int i = 0; i < 256; i++) {
      if (freqMap[i] > 0) {
        heap.insert(HuffmanNode(byteValue: i, frequency: freqMap[i]));
      }
    }

    if (heap.length == 1) {
      final singleNode = heap.extractMin();
      final parent = HuffmanNode(
        frequency: singleNode.frequency,
        left: singleNode,
      );
      heap.insert(parent);
    }

    // 3. Build Huffman Tree
    while (heap.length > 1) {
      final left = heap.extractMin();
      final right = heap.extractMin();
      final parent = HuffmanNode(
        frequency: left.frequency + right.frequency,
        left: left,
        right: right,
      );
      heap.insert(parent);
    }

    final root = heap.extractMin();

    // 4. Generate Code Table
    final codeTable = <int, String>{};
    _generateCodes(root, "", codeTable);

    // 5. Serialize Header
    final builder = BytesBuilder();
    builder.add(magicHeader);
    builder.add(_int64ToBytes(inputData.length));

    int uniqueCount = freqMap.where((f) => f > 0).length;
    builder.add(_int16ToBytes(uniqueCount));
    for (int i = 0; i < 256; i++) {
      if (freqMap[i] > 0) {
        builder.addByte(i);
        builder.add(_int32ToBytes(freqMap[i]));
      }
    }

    // 6. Encode Data Bit by Bit
    List<int> bitBuffer = [];
    for (var byte in inputData) {
      String code = codeTable[byte]!;
      for (int i = 0; i < code.length; i++) {
        bitBuffer.add(code[i] == '1' ? 1 : 0);
      }
    }

    List<int> compressedBytes = [];
    int currentByte = 0;
    int bitCount = 0;

    for (int bit in bitBuffer) {
      currentByte = (currentByte << 1) | bit;
      bitCount++;
      if (bitCount == 8) {
        compressedBytes.add(currentByte);
        currentByte = 0;
        bitCount = 0;
      }
    }

    if (bitCount > 0) {
      currentByte = currentByte << (8 - bitCount);
      compressedBytes.add(currentByte);
    }

    builder.add(compressedBytes);
    return builder.toBytes();
  }

  static Archive decodeZipArchive(Uint8List zipData) {
    try {
      final archive = ZipDecoder().decodeBytes(zipData);

      if (archive.isEmpty) {
        throw FormatException("ZIP file is empty.");
      }

      return archive;
    } catch (e) {
      throw FormatException("Invalid or corrupted ZIP file: $e");
    }
  }

  static Archive decompressZip(Uint8List zipData) {
    try {
      final archive = ZipDecoder().decodeBytes(zipData);

      if (archive.isEmpty) {
        throw FormatException("ZIP file is empty.");
      }

      return archive;
    } catch (e) {
      throw FormatException("Invalid or corrupted ZIP file: $e");
    }
  }

  static List<int> compressToZip(List<int> fileBytes, String originalFileName) {
    final archive = Archive();

    final archiveFile = ArchiveFile(
      originalFileName,
      fileBytes.length,
      fileBytes,
    );

    archive.addFile(archiveFile);

    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive);
  }

  static Uint8List decompress(Uint8List compressedData) {
    if (compressedData.length < 14) {
      throw FormatException("Corrupted header or invalid compressed file.");
    }

    int ptr = 0;
    for (int i = 0; i < 4; i++) {
      if (compressedData[ptr++] != magicHeader[i]) {
        throw FormatException("Invalid Huffman signature header.");
      }
    }

    int originalSize = _bytesToInt64(compressedData.sublist(ptr, ptr + 8));
    ptr += 8;

    if (originalSize == 0) return Uint8List(0);

    int uniqueCount = _bytesToInt16(compressedData.sublist(ptr, ptr + 2));
    ptr += 2;

    final freqMap = List<int>.filled(256, 0);
    for (int i = 0; i < uniqueCount; i++) {
      int byteVal = compressedData[ptr++];
      int freq = _bytesToInt32(compressedData.sublist(ptr, ptr + 4));
      ptr += 4;
      freqMap[byteVal] = freq;
    }

    final heap = MinHeap<HuffmanNode>();
    for (int i = 0; i < 256; i++) {
      if (freqMap[i] > 0) {
        heap.insert(HuffmanNode(byteValue: i, frequency: freqMap[i]));
      }
    }

    if (heap.length == 1) {
      final singleNode = heap.extractMin();
      final parent = HuffmanNode(
        frequency: singleNode.frequency,
        left: singleNode,
      );
      heap.insert(parent);
    }

    while (heap.length > 1) {
      final left = heap.extractMin();
      final right = heap.extractMin();
      final parent = HuffmanNode(
        frequency: left.frequency + right.frequency,
        left: left,
        right: right,
      );
      heap.insert(parent);
    }

    final root = heap.extractMin();

    List<int> decompressed = [];
    HuffmanNode current = root;

    for (int i = ptr; i < compressedData.length; i++) {
      int byte = compressedData[i];
      for (int bitPos = 7; bitPos >= 0; bitPos--) {
        int bit = (byte >> bitPos) & 1;
        current = (bit == 0) ? current.left! : current.right!;

        if (current.isLeaf) {
          decompressed.add(current.byteValue!);
          if (decompressed.length == originalSize) {
            return Uint8List.fromList(decompressed);
          }
          current = root;
        }
      }
    }

    return Uint8List.fromList(decompressed);
  }

  static void _generateCodes(
    HuffmanNode? node,
    String code,
    Map<int, String> table,
  ) {
    if (node == null) return;
    if (node.isLeaf) {
      table[node.byteValue!] = code.isEmpty ? "0" : code;
      return;
    }
    _generateCodes(node.left, "${code}0", table);
    _generateCodes(node.right, "${code}1", table);
  }

  static Uint8List _int64ToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value = value >> 8;
    }
    return bytes;
  }

  static int _bytesToInt64(Uint8List bytes) {
    int value = 0;
    for (int i = 0; i < 8; i++) {
      value = (value << 8) | bytes[i];
    }
    return value;
  }

  static Uint8List _int32ToBytes(int value) {
    final b = ByteData(4)..setInt32(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static int _bytesToInt32(Uint8List bytes) {
    return ByteData.sublistView(bytes).getInt32(0, Endian.big);
  }

  static Uint8List _int16ToBytes(int value) {
    final b = ByteData(2)..setInt16(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static int _bytesToInt16(Uint8List bytes) {
    return ByteData.sublistView(bytes).getInt16(0, Endian.big);
  }
}
