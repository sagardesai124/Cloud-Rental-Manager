/// Add / Edit Work Order, Admin and Staff: web's rule for Billable To Tenant
/// on a property nobody can be billed for (AddWorkorder.jsx with
/// utils/workOrderBillable.js).
library;

/// Web's NO_BILLABLE_TENANT_MESSAGE.
const String kNoBillableTenantMessage =
    'This property has no active lease or tenant to bill. Uncheck "Billable To Tenant" to save the work order.';

/// Where the tenant lookup for the chosen property or unit stands. Only
/// [loaded] means it answered, so an empty list then means "nobody to bill"
/// rather than "still loading" or "the lookup failed".
enum TenantLookup { idle, loading, loaded }

/// Web's hasNoBillableTenant: true only once the tenant lookup for the
/// chosen property or unit has answered with nobody AND no tenant is already
/// on the work order. An edit of an older work order can still carry its
/// billed tenant after that lease ended, and a lookup that is still running
/// or failed is not "nobody", so neither is blocked.
bool hasNoBillableTenant({
  required bool isBillable,
  required String? rentalId,
  required String? tenantId,
  required TenantLookup lookup,
  required int tenantCount,
}) =>
    isBillable &&
    (rentalId ?? '').trim().isNotEmpty &&
    (tenantId ?? '').trim().isEmpty &&
    lookup == TenantLookup.loaded &&
    tenantCount == 0;

/// Web's tenant lookup: the unit's tenants once a unit is picked, otherwise
/// the whole property's (a property with no units, or none picked yet).
String tenantLookupPath(String rentalId, String? unitId) {
  final unit = (unitId ?? '').trim();
  return unit.isEmpty
      ? 'leases/get_tenants/$rentalId'
      : 'leases/get_tenants/$rentalId/$unit';
}
