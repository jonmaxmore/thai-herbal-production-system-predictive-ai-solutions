import 'package:neo4j_driver/neo4j_driver.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/core/errors/exceptions.dart';
import 'package:backend/core/errors/failures.dart';
import 'package:backend/core/utils/either.dart';
import 'package:backend/core/utils/logger.dart';

/// Abstract base class for Neo4j repositories
abstract class Neo4jRepository {
  Future<Either<Failure, List<Record>>> runQuery(
    String cypherQuery, {
    Map<String, dynamic>? parameters,
    bool readOnly = true,
  });
}

/// Implementation of Neo4j repository using the official Neo4j Dart driver
class Neo4jRepositoryImpl implements Neo4jRepository {
  final EnvConfig _config;
  late final Driver _driver;
  bool _isConnected = false;

  Neo4jRepositoryImpl(this._config) {
    _initializeDriver();
  }

  /// Initialize the Neo4j driver with configuration
  void _initializeDriver() {
    try {
      final authToken = AuthTokens.basic(
        _config.neo4jUsername,
        _config.neo4jPassword,
      );

      _driver = Driver(
        Uri.parse(_config.neo4jUri),
        authToken,
        driverConfig: DriverConfig(
          maxConnectionPoolSize: _config.neo4jPoolSize,
          connectionTimeout: Duration(seconds: _config.neo4jTimeout),
          encrypted: _config.neo4jEncrypted,
        ),
      );
    } catch (e) {
      throw Neo4jConnectionException(
        'Failed to initialize Neo4j driver: $e',
      );
    }
  }

  /// Connect to the Neo4j database
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      await _driver.verifyConnectivity();
      _isConnected = true;
      Logger.info('✅ Successfully connected to Neo4j database');
    } catch (e) {
      _isConnected = false;
      throw Neo4jConnectionException(
        'Failed to connect to Neo4j database: $e',
      );
    }
  }

  /// Execute a Cypher query on the Neo4j database
  @override
  Future<Either<Failure, List<Record>>> runQuery(
    String cypherQuery, {
    Map<String, dynamic>? parameters,
    bool readOnly = true,
  }) async {
    if (!_isConnected) {
      await connect();
    }

    final session = _driver.session(
      SessionConfig(database: _config.neo4jDatabase, defaultAccessMode: readOnly 
          ? AccessMode.read 
          : AccessMode.write,
      ),
    );

    try {
      final result = await session.run(cypherQuery, parameters ?? {});
      final records = await result.toList();
      return Right(records);
    } on Neo4jException catch (e) {
      Logger.error('Neo4j query error: ${e.code} - ${e.message}');
      return Left(Neo4jFailure('Neo4j operation failed: ${e.message}'));
    } catch (e) {
      Logger.error('Unexpected error during Neo4j operation: $e');
      return Left(UnhandledFailure('Unexpected error: $e'));
    } finally {
      await session.close();
    }
  }

  /// Execute multiple queries in a single transaction
  Future<Either<Failure, List<List<Record>>>> runTransaction(
    List<TransactionQuery> queries,
  ) async {
    if (!_isConnected) {
      await connect();
    }

    final session = _driver.session(
      SessionConfig(
        database: _config.neo4jDatabase,
        defaultAccessMode: AccessMode.write,
      ),
    );

    try {
      final results = await session.executeWrite((tx) async {
        final allResults = <List<Record>>[];
        for (final query in queries) {
          final result = await tx.run(query.cypher, query.parameters ?? {});
          allResults.add(await result.toList());
        }
        return allResults;
      });
      return Right(results);
    } on Neo4jException catch (e) {
      Logger.error('Neo4j transaction error: ${e.code} - ${e.message}');
      return Left(Neo4jFailure('Transaction failed: ${e.message}'));
    } catch (e) {
      Logger.error('Unexpected error during Neo4j transaction: $e');
      return Left(UnhandledFailure('Unexpected error: $e'));
    } finally {
      await session.close();
    }
  }

  /// Close the database connection
  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      await _driver.close();
      _isConnected = false;
      Logger.info('🔌 Disconnected from Neo4j database');
    } catch (e) {
      Logger.error('Failed to disconnect from Neo4j: $e');
    }
  }
}

/// Represents a query in a transaction
class TransactionQuery {
  final String cypher;
  final Map<String, dynamic>? parameters;

  TransactionQuery(this.cypher, {this.parameters});
}

/// Extension for working with Neo4j records
extension RecordExtensions on Record {
  /// Get a value from the record by key
  dynamic getValue(String key) {
    return this[key];
  }

  /// Get a node from the record by key
  Node? getNode(String key) {
    final value = getValue(key);
    return value is Node ? value : null;
  }

  /// Get a relationship from the record by key
  Relationship? getRelationship(String key) {
    final value = getValue(key);
    return value is Relationship ? value : null;
  }

  /// Convert a node to a map
  Map<String, dynamic> nodeToMap(Node node) {
    return {
      'id': node.id.toString(),
      'labels': node.labels.toList(),
      'properties': node.properties,
    };
  }

  /// Convert a relationship to a map
  Map<String, dynamic> relationshipToMap(Relationship relationship) {
    return {
      'id': relationship.id.toString(),
      'type': relationship.type,
      'startNodeId': relationship.startNodeId.toString(),
      'endNodeId': relationship.endNodeId.toString(),
      'properties': relationship.properties,
    };
  }
}

/// Extension for Cypher query building
extension CypherQueryBuilder on String {
  /// Create a Cypher query to find a node by ID
  String findNodeById(String label, String id) {
    return '''
      MATCH (node:$label {id: \$id})
      RETURN node
    ''';
  }

  /// Create a Cypher query to find nodes by properties
  String findNodesByProperties(String label, Map<String, dynamic> properties) {
    final whereClause = properties.keys
        .map((key) => 'node.$key = \$$key')
        .join(' AND ');
    
    return '''
      MATCH (node:$label)
      WHERE $whereClause
      RETURN node
    ''';
  }

  /// Create a Cypher query to create a node
  String createNode(String label, Map<String, dynamic> properties) {
    final propertyKeys = properties.keys.join(', ');
    final propertyValues = properties.keys.map((k) => '\$$k').join(', ');
    
    return '''
      CREATE (node:$label { $propertyKeys })
      SET node += { $propertyValues }
      RETURN node
    ''';
  }

  /// Create a Cypher query to update a node
  String updateNode(String label, String id, Map<String, dynamic> updates) {
    final setClause = updates.keys
        .map((key) => 'node.$key = \$$key')
        .join(', ');
    
    return '''
      MATCH (node:$label {id: \$id})
      SET $setClause
      RETURN node
    ''';
  }

  /// Create a Cypher query to create a relationship
  String createRelationship(
    String fromLabel,
    String fromId,
    String toLabel,
    String toId,
    String relType,
    Map<String, dynamic>? properties,
  ) {
    final relProps = properties != null
        ? '{ ${properties.keys.map((k) => '$k: \$$k').join(', ')} }'
        : '';
    
    return '''
      MATCH (a:$fromLabel {id: \$fromId}), (b:$toLabel {id: \$toId})
      CREATE (a)-[r:$relType $relProps]->(b)
      RETURN r
    ''';
  }

  /// Create a Cypher query to traverse the graph
  String traverseGraph(
    String startLabel,
    String startId,
    String relationshipType,
    String endLabel,
    int depth,
  ) {
    return '''
      MATCH (start:$startLabel {id: \$startId})
      CALL apoc.path.subgraphNodes(start, {
        relationshipFilter: '$relationshipType',
        labelFilter: '>$endLabel',
        minLevel: 1,
        maxLevel: $depth
      }) YIELD node
      RETURN node
    ''';
  }
}
