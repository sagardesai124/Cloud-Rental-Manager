import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';

/// Add Lease's selected-tenant list (shared by Admin and Staff): the same
/// person is never added twice, but different people always can be.
/// Before: a tenant typed in on the form (no tenant id yet) was compared by
/// applicant id, which is empty for almost everyone, so it was silently
/// dropped whenever the lease already had any non-applicant tenant.

Tenant _saved(String id, {String email = ''}) =>
    Tenant(tenantId: id, tenantFirstName: id, tenantEmail: email);

Tenant _new(String name, String email) =>
    Tenant(tenantFirstName: name, tenantEmail: email);

void main() {
  late SelectedTenantsProvider list;
  setUp(() => list = SelectedTenantsProvider());

  List<String?> names() =>
      list.selectedTenants.map((t) => t.tenantFirstName).toList();

  test('a new tenant can be added next to an existing tenant', () {
    list.addTenant(_saved('T-1', email: 'ruth@example.com'));
    list.addTenant(_new('Jane', 'jane@example.com'));
    expect(names(), ['T-1', 'Jane']);
  });

  test('two different new tenants can both be added', () {
    list.addTenant(_new('Jane', 'jane@example.com'));
    list.addTenant(_new('Sam', 'sam@example.com'));
    expect(names(), ['Jane', 'Sam']);
    expect(list.rentShareControllers, hasLength(2));
  });

  test('the same new tenant is not added twice (email, any letter case)', () {
    list.addTenant(_new('Jane', 'jane@example.com'));
    list.addTenant(_new('Jane', ' JANE@example.com '));
    expect(names(), ['Jane']);
  });

  test('a new tenant with an existing tenant\'s email is not added again', () {
    list.addTenant(_saved('T-1', email: 'ruth@example.com'));
    list.addTenant(_new('Ruth', 'Ruth@Example.com'));
    expect(names(), ['T-1']);
  });

  test('an existing tenant is not added twice', () {
    list.addTenant(_saved('T-1'));
    list.addTenant(_saved('T-1'));
    expect(names(), ['T-1']);
  });

  test('a saved tenant with an already-typed-in tenant\'s email is refused too',
      () {
    expect(list.addTenant(_new('Ruth', 'ruth@example.com')), isTrue);
    expect(list.addTenant(_saved('T-1', email: 'RUTH@example.com')), isFalse);
    expect(names(), ['Ruth']);
    expect(list.isAdded(_saved('T-1', email: 'ruth@example.com')), isTrue);
  });

  test('two saved tenants are never merged by email (Edit Lease keeps both)', () {
    list.addTenant(_saved('T-1', email: 'shared@example.com'));
    list.addTenant(_saved('T-2', email: 'shared@example.com'));
    expect(names(), ['T-1', 'T-2']);
  });

  test('unticking a row removes the same person even if added as another object',
      () {
    list.addTenant(_new('Ruth', 'ruth@example.com'));
    list.removeTenant(_saved('T-1', email: 'ruth@example.com'));
    expect(list.selectedTenants, isEmpty);
    expect(list.rentShareControllers, isEmpty);
  });

  test('applicants still match by applicant id', () {
    list.addTenant(Tenant(applicantId: 'A-1', tenantFirstName: 'Pat'));
    list.addTenant(Tenant(applicantId: 'A-1', tenantFirstName: 'Pat'));
    list.addTenant(Tenant(applicantId: 'A-2', tenantFirstName: 'Lee'));
    expect(names(), ['Pat', 'Lee']);
  });
}
