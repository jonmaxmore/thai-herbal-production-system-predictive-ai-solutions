import 'package:backend/core/cqrs/commands/command_handler.dart';
import 'package:backend/core/cqrs/commands/command.dart';
import 'package:backend/core/domain/entities/herb_entity.dart';
import 'package:backend/core/domain/repositories/herb_repository.dart';
import 'package:backend/core/errors/failures.dart';
import 'package:backend/core/utils/either.dart';
import 'package:backend/core/utils/uuid_generator.dart';
import 'package:backend/core/domain/value_objects/herb_value_objects.dart';

/// Parameters for creating a new herb
class CreateHerbParams extends CommandParams {
  final HerbName name;
  final ScientificName scientificName;
  final HerbDescription description;
  final List<MedicinalProperty> medicinalProperties;
  final String createdBy;

  CreateHerbParams({
    required this.name,
    required this.scientificName,
    required this.description,
    required this.medicinalProperties,
    required this.createdBy,
  });

  @override
  List<String> validate() {
    final errors = <String>[];
    
    if (name.value.isEmpty) {
      errors.add('Herb name is required');
    }
    
    if (scientificName.value.isEmpty) {
      errors.add('Scientific name is required');
    }
    
    if (medicinalProperties.isEmpty) {
      errors.add('At least one medicinal property is required');
    }
    
    if (createdBy.isEmpty) {
      errors.add('Creator ID is required');
    }
    
    return errors;
  }
}

/// Command for creating a new herb
class CreateHerbCommand implements Command<Herb, CreateHerbParams> {
  final HerbRepository repository;

  CreateHerbCommand(this.repository);

  @override
  Future<Either<Failure, Herb>> call(CreateHerbParams params) async {
    try {
      // Create new herb entity
      final herb = Herb(
        id: HerbId(UuidGenerator.generateV4()),
        name: params.name,
        scientificName: params.scientificName,
        description: params.description,
        medicinalProperties: params.medicinalProperties,
        createdAt: DateTime.now(),
        createdBy: params.createdBy,
        updatedAt: DateTime.now(),
        updatedBy: params.createdBy,
        isCertified: false,
        certificationId: null,
      );
      
      // Save to repository
      final savedHerb = await repository.create(herb);
      
      return Right(savedHerb);
    } on HerbCreationFailure catch (e) {
      return Left(HerbCreationFailure('Failed to create herb: ${e.message}'));
    } catch (e) {
      return Left(UnhandledFailure('Unexpected error: $e'));
    }
  }
}

/// Handler for CreateHerbCommand
class CreateHerbCommandHandler 
    implements CommandHandler<CreateHerbCommand, Herb, CreateHerbParams> {
  
  final HerbRepository repository;

  CreateHerbCommandHandler(this.repository);

  @override
  Future<Either<Failure, Herb>> execute(CreateHerbParams params) async {
    final command = CreateHerbCommand(repository);
    return command(params);
  }
}

/// Parameters for updating an existing herb
class UpdateHerbParams extends CommandParams {
  final HerbId herbId;
  final HerbName? name;
  final ScientificName? scientificName;
  final HerbDescription? description;
  final List<MedicinalProperty>? medicinalProperties;
  final String updatedBy;

  UpdateHerbParams({
    required this.herbId,
    this.name,
    this.scientificName,
    this.description,
    this.medicinalProperties,
    required this.updatedBy,
  });

  @override
  List<String> validate() {
    final errors = <String>[];
    
    if (herbId.value.isEmpty) {
      errors.add('Herb ID is required');
    }
    
    if (name?.value.isEmpty ?? false) {
      errors.add('Herb name cannot be empty');
    }
    
    if (scientificName?.value.isEmpty ?? false) {
      errors.add('Scientific name cannot be empty');
    }
    
    if (medicinalProperties?.isEmpty ?? false) {
      errors.add('Medicinal properties cannot be empty');
    }
    
    if (updatedBy.isEmpty) {
      errors.add('Updater ID is required');
    }
    
    return errors;
  }
}

/// Command for updating an existing herb
class UpdateHerbCommand implements Command<Herb, UpdateHerbParams> {
  final HerbRepository repository;

  UpdateHerbCommand(this.repository);

  @override
  Future<Either<Failure, Herb>> call(UpdateHerbParams params) async {
    try {
      // Get existing herb
      final existingHerb = await repository.findById(params.herbId);
      if (existingHerb == null) {
        return Left(HerbNotFoundFailure('Herb not found with ID: ${params.herbId}'));
      }
      
      // Create updated herb entity
      final updatedHerb = existingHerb.copyWith(
        name: params.name ?? existingHerb.name,
        scientificName: params.scientificName ?? existingHerb.scientificName,
        description: params.description ?? existingHerb.description,
        medicinalProperties: params.medicinalProperties ?? existingHerb.medicinalProperties,
        updatedAt: DateTime.now(),
        updatedBy: params.updatedBy,
      );
      
      // Save to repository
      final savedHerb = await repository.update(updatedHerb);
      
      return Right(savedHerb);
    } on HerbUpdateFailure catch (e) {
      return Left(HerbUpdateFailure('Failed to update herb: ${e.message}'));
    } catch (e) {
      return Left(UnhandledFailure('Unexpected error: $e'));
    }
  }
}

/// Handler for UpdateHerbCommand
class UpdateHerbCommandHandler 
    implements CommandHandler<UpdateHerbCommand, Herb, UpdateHerbParams> {
  
  final HerbRepository repository;

  UpdateHerbCommandHandler(this.repository);

  @override
  Future<Either<Failure, Herb>> execute(UpdateHerbParams params) async {
    final command = UpdateHerbCommand(repository);
    return command(params);
  }
}

/// Parameters for certifying a herb
class CertifyHerbParams extends CommandParams {
  final HerbId herbId;
  final String certificationId;
  final String certifiedBy;

  CertifyHerbParams({
    required this.herbId,
    required this.certificationId,
    required this.certifiedBy,
  });

  @override
  List<String> validate() {
    final errors = <String>[];
    
    if (herbId.value.isEmpty) {
      errors.add('Herb ID is required');
    }
    
    if (certificationId.isEmpty) {
      errors.add('Certification ID is required');
    }
    
    if (certifiedBy.isEmpty) {
      errors.add('Certifier ID is required');
    }
    
    return errors;
  }
}

/// Command for certifying a herb
class CertifyHerbCommand implements Command<Herb, CertifyHerbParams> {
  final HerbRepository repository;

  CertifyHerbCommand(this.repository);

  @override
  Future<Either<Failure, Herb>> call(CertifyHerbParams params) async {
    try {
      // Get existing herb
      final herb = await repository.findById(params.herbId);
      if (herb == null) {
        return Left(HerbNotFoundFailure('Herb not found with ID: ${params.herbId}'));
      }
      
      // Update certification status
      final certifiedHerb = herb.copyWith(
        isCertified: true,
        certificationId: params.certificationId,
        updatedAt: DateTime.now(),
        updatedBy: params.certifiedBy,
      );
      
      // Save to repository
      final savedHerb = await repository.update(certifiedHerb);
      
      return Right(savedHerb);
    } on HerbUpdateFailure catch (e) {
      return Left(HerbUpdateFailure('Failed to certify herb: ${e.message}'));
    } catch (e) {
      return Left(UnhandledFailure('Unexpected error: $e'));
    }
  }
}

/// Handler for CertifyHerbCommand
class CertifyHerbCommandHandler 
    implements CommandHandler<CertifyHerbCommand, Herb, CertifyHerbParams> {
  
  final HerbRepository repository;

  CertifyHerbCommandHandler(this.repository);

  @override
  Future<Either<Failure, Herb>> execute(CertifyHerbParams params) async {
    final command = CertifyHerbCommand(repository);
    return command(params);
  }
}

/// Parameters for deleting a herb
class DeleteHerbParams extends CommandParams {
  final HerbId herbId;
  final String deletedBy;

  DeleteHerbParams({
    required this.herbId,
    required this.deletedBy,
  });

  @override
  List<String> validate() {
    final errors = <String>[];
    
    if (herbId.value.isEmpty) {
      errors.add('Herb ID is required');
    }
    
    if (deletedBy.isEmpty) {
      errors.add('Deleter ID is required');
    }
    
    return errors;
  }
}

/// Command for deleting a herb
class DeleteHerbCommand implements Command<void, DeleteHerbParams> {
  final HerbRepository repository;

  DeleteHerbCommand(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteHerbParams params) async {
    try {
      // Check if herb exists
      final exists = await repository.exists(params.herbId);
      if (!exists) {
        return Left(HerbNotFoundFailure('Herb not found with ID: ${params.herbId}'));
      }
      
      // Soft delete the herb
      await repository.softDelete(params.herbId, params.deletedBy);
      
      return const Right(null);
    } on HerbDeletionFailure catch (e) {
      return Left(HerbDeletionFailure('Failed to delete herb: ${e.message}'));
    } catch (e) {
      return Left(UnhandledFailure('Unexpected error: $e'));
    }
  }
}

/// Handler for DeleteHerbCommand
class DeleteHerbCommandHandler 
    implements CommandHandler<DeleteHerbCommand, void, DeleteHerbParams> {
  
  final HerbRepository repository;

  DeleteHerbCommandHandler(this.repository);

  @override
  Future<Either<Failure, void>> execute(DeleteHerbParams params) async {
    final command = DeleteHerbCommand(repository);
    return command(params);
  }
}

/// Composite command for creating and certifying a herb in one transaction
class CreateAndCertifyHerbCommand implements Command<Herb, CreateHerbParams> {
  final HerbRepository repository;
  final String certificationId;
  final String certifiedBy;

  CreateAndCertifyHerbCommand({
    required this.repository,
    required this.certificationId,
    required this.certifiedBy,
  });

  @override
  Future<Either<Failure, Herb>> call(CreateHerbParams params) async {
    try {
      // Create the herb
      final createCommand = CreateHerbCommand(repository);
      final createResult = await createCommand(params);
      
      if (createResult.isLeft()) {
        return createResult;
      }
      
      final herb = (createResult as Right).value;
      
      // Certify the herb
      final certifyParams = CertifyHerbParams(
        herbId: herb.id,
        certificationId: certificationId,
        certifiedBy: certifiedBy,
      );
      
      final certifyCommand = CertifyHerbCommand(repository);
      final certifyResult = await certifyCommand(certifyParams);
      
      return certifyResult;
    } catch (e) {
      return Left(UnhandledFailure('Failed to create and certify herb: $e'));
    }
  }
}

/// Handler for CreateAndCertifyHerbCommand
class CreateAndCertifyHerbCommandHandler 
    implements CommandHandler<CreateAndCertifyHerbCommand, Herb, CreateHerbParams> {
  
  final HerbRepository repository;
  final String certificationId;
  final String certifiedBy;

  CreateAndCertifyHerbCommandHandler({
    required this.repository,
    required this.certificationId,
    required this.certifiedBy,
  });

  @override
  Future<Either<Failure, Herb>> execute(CreateHerbParams params) async {
    final command = CreateAndCertifyHerbCommand(
      repository: repository,
      certificationId: certificationId,
      certifiedBy: certifiedBy,
    );
    
    return command(params);
  }
}

/// Command for batch importing herbs
class ImportHerbsCommand implements Command<int, List<CreateHerbParams>> {
  final HerbRepository repository;

  ImportHerbsCommand(this.repository);

  @override
  Future<Either<Failure, int>> call(List<CreateHerbParams> paramsList) async {
    try {
      int successCount = 0;
      
      for (final params in paramsList) {
        final result = await CreateHerbCommand(repository)(params);
        if (result.isRight()) {
          successCount++;
        }
      }
      
      return Right(successCount);
    } catch (e) {
      return Left(HerbImportFailure('Failed to import herbs: $e'));
    }
  }
}

/// Handler for ImportHerbsCommand
class ImportHerbsCommandHandler 
    implements CommandHandler<ImportHerbsCommand, int, List<CreateHerbParams>> {
  
  final HerbRepository repository;

  ImportHerbsCommandHandler(this.repository);

  @override
  Future<Either<Failure, int>> execute(List<CreateHerbParams> params) async {
    final command = ImportHerbsCommand(repository);
    return command(params);
  }
}
