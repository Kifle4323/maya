import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cbhi_data.dart';

class FamilyState extends Equatable {
  const FamilyState({
    required this.members,
    required this.isLoading,
    required this.isSaving,
    this.error,
    this.lastSetupCode,
  });

  factory FamilyState.initial() => const FamilyState(
    members: <FamilyMember>[],
    isLoading: false,
    isSaving: false,
  );

  final List<FamilyMember> members;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? lastSetupCode;

  FamilyState copyWith({
    List<FamilyMember>? members,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? lastSetupCode,
    bool clearError = false,
  }) {
    return FamilyState(
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
      lastSetupCode: lastSetupCode ?? this.lastSetupCode,
    );
  }

  @override
  List<Object?> get props => [members, isLoading, isSaving, error, lastSetupCode];
}

class MyFamilyCubit extends Cubit<FamilyState> {
  MyFamilyCubit(this.repository) : super(FamilyState.initial());

  final CbhiRepository repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final snapshot = await repository.loadCachedSnapshot();
      final remote = await repository.fetchMyFamily();
      emit(
        state.copyWith(
          members: remote.isEmpty ? snapshot.familyMembers : remote,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      final snapshot = await repository.loadCachedSnapshot();
      emit(
        state.copyWith(
          members: snapshot.familyMembers,
          isLoading: false,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> addMember(FamilyMemberDraft draft) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final result = await repository.addFamilyMember(draft);
      emit(state.copyWith(members: result.members, isSaving: false, clearError: true, lastSetupCode: result.setupCode));
    } catch (error) {
      emit(state.copyWith(isSaving: false, error: error.toString()));
    }
  }

  Future<void> updateMember(String memberId, FamilyMemberDraft draft) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final members = await repository.updateFamilyMember(memberId, draft);
      emit(state.copyWith(members: members, isSaving: false, clearError: true));
    } catch (error) {
      emit(state.copyWith(isSaving: false, error: error.toString()));
    }
  }

  Future<void> removeMember(String memberId) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final members = await repository.removeFamilyMember(memberId);
      emit(state.copyWith(members: members, isSaving: false, clearError: true));
    } catch (error) {
      emit(state.copyWith(isSaving: false, error: error.toString()));
    }
  }

  void clear() {
    emit(FamilyState.initial());
  }
}
