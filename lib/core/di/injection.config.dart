// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:hive_flutter/hive_flutter.dart' as _i986;
import 'package:injectable/injectable.dart' as _i526;
import 'package:pacify/core/di/injection.dart' as _i355;
import 'package:pacify/data/datasources/local/todo_local_datasource.dart'
    as _i296;
import 'package:pacify/data/datasources/remote/todo_remote_datasource.dart'
    as _i347;
import 'package:pacify/data/models/todo_model.dart' as _i288;
import 'package:pacify/domain/repositories/todo_repository.dart' as _i984;
import 'package:pacify/presentation/todos/todos.dart' as _i253;
import 'package:talker/talker.dart' as _i993;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    final dataSourceModule = _$DataSourceModule();
    final repositoryModule = _$RepositoryModule();
    final blocModule = _$BlocModule();
    gh.singleton<_i993.Talker>(() => registerModule.talker);
    await gh.singletonAsync<_i986.Box<_i288.TodoModel>>(
      () => registerModule.todoBox,
      preResolve: true,
    );
    gh.singleton<_i296.TodoLocalDataSource>(() =>
        dataSourceModule.todoLocalDataSource(gh<_i986.Box<_i288.TodoModel>>()));
    gh.singleton<_i361.Dio>(() => registerModule.dio(gh<_i993.Talker>()));
    gh.singleton<_i347.TodoRemoteDataSource>(
        () => dataSourceModule.todoRemoteDataSource(gh<_i361.Dio>()));
    gh.singleton<_i984.TodoRepository>(() => repositoryModule.todoRepository(
          gh<_i347.TodoRemoteDataSource>(),
          gh<_i296.TodoLocalDataSource>(),
        ));
    gh.singleton<_i253.TodoBloc>(
        () => blocModule.todoBloc(gh<_i984.TodoRepository>()));
    return this;
  }
}

class _$RegisterModule extends _i355.RegisterModule {}

class _$DataSourceModule extends _i355.DataSourceModule {}

class _$RepositoryModule extends _i355.RepositoryModule {}

class _$BlocModule extends _i355.BlocModule {}
