import 'package:mongo_dart/mongo_dart.dart';

class ObjectIdHelper {
  /// Converts various ID formats to a valid MongoDB ObjectId
  /// Handles:
  /// - Proper 24-character hex ObjectIds
  /// - ObjectId("hex") string format
  /// - Timestamp-based IDs (converts to ObjectId)
  /// - Invalid formats (throws descriptive error)
  static ObjectId parseObjectId(dynamic id) {
    if (id == null) {
      throw ArgumentError('ID cannot be null');
    }

    // If it's already an ObjectId, return it
    if (id is ObjectId) {
      return id;
    }

    // Convert to string and clean it
    final idStr = id.toString().replaceAll('"', '').trim();

    // Handle empty string
    if (idStr.isEmpty) {
      throw ArgumentError('ID cannot be empty');
    }

    // Try to parse ObjectId("hex") format
    final objectIdMatch = RegExp(r'ObjectId\(["\x27]?([a-fA-F0-9]{24})["\x27]?\)')
        .firstMatch(idStr);
    if (objectIdMatch != null) {
      return ObjectId.fromHexString(objectIdMatch.group(1)!);
    }

    // Try to parse plain 24-character hex string
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(idStr)) {
      return ObjectId.fromHexString(idStr);
    }

    // Handle timestamp-based IDs (convert to ObjectId)
    if (RegExp(r'^\d+$').hasMatch(idStr)) {
      // This is a timestamp ID, create a new ObjectId for it
      // We'll create a deterministic ObjectId based on the timestamp
      return _createObjectIdFromTimestamp(int.parse(idStr));
    }

    // If none of the above worked, throw an error
    throw ArgumentError('Invalid ObjectId format: $id. '
        'Expected 24-character hex string, ObjectId("hex") format, or timestamp.');
  }

  /// Creates a deterministic ObjectId from a timestamp
  /// This ensures that the same timestamp always produces the same ObjectId
  static ObjectId _createObjectIdFromTimestamp(int timestamp) {
    // Convert timestamp to a 24-character hex string
    // We'll use the timestamp as the first part and pad with zeros
    final timestampHex = timestamp.toRadixString(16).padLeft(8, '0');
    
    // Create a deterministic suffix based on the timestamp
    // This ensures consistency across app restarts
    final suffix = (timestamp % 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final padding = '00000000'; // 8 characters
    final additionalPadding = '00'; // 2 characters to make it 24 total
    
    final hexString = timestampHex + suffix + padding + additionalPadding;
    
    // Ensure it's exactly 24 characters
    final finalHex = hexString.substring(0, 24);
    
    return ObjectId.fromHexString(finalHex);
  }

  /// Safely converts an ObjectId to a hex string
  static String toHexString(dynamic id) {
    if (id == null) {
      throw ArgumentError('ID cannot be null');
    }

    if (id is ObjectId) {
      return id.toHexString();
    }

    // Try to parse it first, then convert to hex
    final objectId = parseObjectId(id);
    return objectId.toHexString();
  }

  /// Checks if an ID is a valid ObjectId format
  static bool isValidObjectId(dynamic id) {
    if (id == null) return false;

    try {
      parseObjectId(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generates a new ObjectId
  static ObjectId generateNew() {
    return ObjectId();
  }

  /// Converts a timestamp-based ID to a proper ObjectId hex string
  /// This is useful for migration scenarios
  static String convertTimestampToObjectIdHex(int timestamp) {
    return _createObjectIdFromTimestamp(timestamp).toHexString();
  }

  /// Checks if an ID is a timestamp-based ID
  static bool isTimestampId(dynamic id) {
    if (id == null) return false;
    final idStr = id.toString().trim();
    return RegExp(r'^\d+$').hasMatch(idStr);
  }

  /// Checks if an ID is already a proper ObjectId format
  static bool isProperObjectId(dynamic id) {
    if (id == null) return false;
    if (id is ObjectId) return true;
    
    final idStr = id.toString().replaceAll('"', '').trim();
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(idStr);
  }
} 