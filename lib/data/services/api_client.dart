import 'package:dio/dio.dart';
import '../../core/constants.dart';
import 'storage_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;
  final _storage = StorageService();
  bool _refreshing = false;
  bool _initialized = false;

  // Set by AuthNotifier so the interceptor can trigger logout on session expiry
  void Function()? onSessionExpired;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.secureBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAccessToken();
        final orgId = await _storage.getActiveOrgId();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        if (orgId  != null) options.headers['x-organization-id'] = orgId;
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_refreshing) {
          _refreshing = true;
          try {
            final refreshToken = await _storage.getRefreshToken();
            if (refreshToken == null) {
              await _storage.clearTokens();
              onSessionExpired?.call();
              handler.reject(error);
              return;
            }
            final res = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
            final newAccess  = res.data['data']['accessToken']  as String;
            final newRefresh = res.data['data']['refreshToken'] as String;
            await _storage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
            error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
            final retryRes = await _dio.fetch(error.requestOptions);
            handler.resolve(retryRes);
          } catch (_) {
            // Only clear tokens — preserve org ID so re-login can restore hasOrg
            // even when the login response omits the organizations list.
            await _storage.clearTokens();
            onSessionExpired?.call(); // notify AuthNotifier → GoRouter redirects to /login
            handler.reject(error);
          } finally {
            _refreshing = false;
          }
        } else {
          handler.next(error);
        }
      },
    ));

    // ── Retry interceptor ─────────────────────────────────────
    // Retries transient network errors up to 3 times with exponential backoff
    // (1 s, 2 s, 4 s). Does NOT retry 4xx/5xx responses — those are real errors.
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        final opts = error.requestOptions;
        final attempt = (opts.extra['_retryCount'] as int? ?? 0);
        final isNetworkError = error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.connectionError;

        if (isNetworkError && attempt < 3) {
          opts.extra['_retryCount'] = attempt + 1;
          await Future.delayed(Duration(seconds: 1 << attempt)); // 1, 2, 4 s
          try {
            handler.resolve(await _dio.fetch(opts));
          } catch (e) {
            handler.next(e as DioException);
          }
          return;
        }
        handler.next(error);
      },
    ));
  }

  Dio get dio {
    if (!_initialized) init();
    return _dio;
  }

  // ── Auth ──────────────────────────────────────────────────────
  Future<Response> login(String email, String password) =>
      dio.post('/auth/login', data: {'email': email, 'password': password});
  Future<Response> register({required String name, required String email, required String password, String? phone}) =>
      dio.post('/auth/register', data: {'name': name, 'email': email, 'password': password, if (phone != null && phone.isNotEmpty) 'phone': phone});
  Future<Response> forgotPassword(String email) =>
      dio.post('/auth/forgot-password', data: {'email': email});
  Future<Response> resetPassword({required String token, required String password}) =>
      dio.post('/auth/reset-password', data: {'token': token, 'password': password});
  Future<Response> logout() => dio.post('/auth/logout');
  Future<Response> getProfile() => dio.get('/auth/profile');
  Future<Response> updateProfile(Map<String, dynamic> data) => dio.patch('/auth/profile', data: data);
  Future<Response> changePassword({required String currentPassword, required String newPassword}) =>
      dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword':     newPassword,
      });

  // ── Organization ──────────────────────────────────────────────
  Future<Response> createOrganization(Map<String, dynamic> data) => dio.post('/organizations', data: data);
  Future<Response> getOrganization() => dio.get('/organizations/current');
  Future<Response> updateOrganization(Map<String, dynamic> data) => dio.patch('/organizations/current', data: data);
  Future<Response> getTeamMembers() => dio.get('/organizations/current/members');
  Future<Response> inviteMember(String email, {String role = 'MEMBER'}) =>
      dio.post('/organizations/current/invite', data: {'email': email, 'role': role});
  Future<Response> getOrgStats() => dio.get('/org-admin/stats');
  Future<Response> getActivityFeed() => dio.get('/org-admin/activity');

  // ── Dashboard ─────────────────────────────────────────────────
  Future<Response> getDashboardStats() => dio.get('/org-admin/stats');

  // ── CRM ───────────────────────────────────────────────────────
  Future<Response> getParties({int page = 1, String search = '', String type = ''}) =>
      dio.get('/parties', queryParameters: {
        'page': page, 'limit': 25,
        if (search.isNotEmpty) 'search': search,
        if (type.isNotEmpty) 'type': type,
      });
  Future<Response> getPartyDetail(String id) => dio.get('/parties/$id');
  Future<Response> createParty(Map<String, dynamic> data) => dio.post('/parties', data: data);
  Future<Response> updateParty(String id, Map<String, dynamic> data) => dio.patch('/parties/$id', data: data);
  Future<Response> deleteParty(String id) => dio.delete('/parties/$id');
  Future<Response> getPartyCommunications(String id) => dio.get('/parties/$id/communications');
  Future<Response> createPartyCommunication(String id, Map<String, dynamic> data) => dio.post('/parties/$id/communications', data: data);

  // ── Leads ─────────────────────────────────────────────────────
  Future<Response> getLeads({int page = 1, String status = ''}) =>
      dio.get('/leads', queryParameters: {
        'page': page, 'limit': 25,
        if (status.isNotEmpty) 'status': status,
      });
  Future<Response> getLeadDetail(String id) => dio.get('/leads/$id');
  Future<Response> createLead(Map<String, dynamic> data) => dio.post('/leads', data: data);
  Future<Response> updateLead(String id, Map<String, dynamic> data) => dio.patch('/leads/$id', data: data);
  Future<Response> updateLeadStatus(String id, String status) =>
      dio.patch('/leads/$id', data: {'status': status});
  Future<Response> deleteLead(String id) => dio.delete('/leads/$id');
  Future<Response> getLeadActivities(String id) => dio.get('/leads/$id/activities');
  Future<Response> createLeadActivity(String id, Map<String, dynamic> data) => dio.post('/leads/$id/activities', data: data);

  // ── Inventory ─────────────────────────────────────────────────
  Future<Response> getProducts({int page = 1, String search = '', String category = ''}) =>
      dio.get('/inventory/products', queryParameters: {
        'page': page, 'limit': 25,
        if (search.isNotEmpty)   'search': search,
        if (category.isNotEmpty) 'category': category,
      });
  Future<Response> getProductDetail(String id) => dio.get('/inventory/products/$id');
  Future<Response> createProduct(Map<String, dynamic> data) => dio.post('/inventory/products', data: data);
  Future<Response> updateProduct(String id, Map<String, dynamic> data) => dio.patch('/inventory/products/$id', data: data);
  Future<Response> deleteProduct(String id) => dio.delete('/inventory/products/$id');
  Future<Response> adjustStock(String id, int qty, String type, String? reason) =>
      dio.post('/inventory/products/$id/adjust', data: {'quantity': qty, 'type': type, 'reason': reason});
  Future<Response> getInventorySummary() => dio.get('/inventory/summary');
  Future<Response> getCategories() => dio.get('/inventory/categories');
  Future<Response> createCategory(String name) => dio.post('/inventory/categories', data: {'name': name});
  Future<Response> updateCategory(String id, Map<String, dynamic> data) => dio.patch('/inventory/categories/$id', data: data);
  Future<Response> deleteCategory(String id) => dio.delete('/inventory/categories/$id');

  // ── Finance ───────────────────────────────────────────────────
  Future<Response> getFinanceSummary() => dio.get('/finance/summary');
  Future<Response> getInvoices({int page = 1, String status = '', String type = ''}) =>
      dio.get('/finance', queryParameters: {
        'page': page, 'limit': 25,
        if (status.isNotEmpty) 'status': status,
        if (type.isNotEmpty)   'type': type,
      });
  Future<Response> getInvoiceDetail(String id) => dio.get('/finance/$id');
  Future<Response> createInvoice(Map<String, dynamic> data) => dio.post('/finance', data: data);
  Future<Response> updateInvoice(String id, Map<String, dynamic> data) => dio.patch('/finance/$id', data: data);
  Future<Response> deleteInvoice(String id) => dio.delete('/finance/$id');
  Future<Response> getPayments({int page = 1, String? invoiceId}) => dio.get('/finance/payments', queryParameters: {'page': page, 'limit': 25, if (invoiceId != null) 'invoiceId': invoiceId});
  Future<Response> createPayment(Map<String, dynamic> data) => dio.post('/finance/payments', data: data);
  Future<Response> deletePayment(String id) => dio.delete('/finance/payments/$id');

  // ── Purchase ──────────────────────────────────────────────────
  Future<Response> getPurchaseOrders({int page = 1, String status = ''}) =>
      dio.get('/purchase-orders', queryParameters: {
        'page': page, 'limit': 25,
        if (status.isNotEmpty) 'status': status,
      });
  Future<Response> getPurchaseOrderDetail(String id) => dio.get('/purchase-orders/$id');
  Future<Response> createPurchaseOrder(Map<String, dynamic> data) => dio.post('/purchase-orders', data: data);
  Future<Response> updatePurchaseOrder(String id, Map<String, dynamic> data) => dio.patch('/purchase-orders/$id', data: data);

  // ── Sales ─────────────────────────────────────────────────────
  Future<Response> getSalesOrders({int page = 1, String status = ''}) =>
      dio.get('/sales-orders', queryParameters: {
        'page': page, 'limit': 25,
        if (status.isNotEmpty) 'status': status,
      });
  Future<Response> getSalesOrderDetail(String id) => dio.get('/sales-orders/$id');
  Future<Response> createSalesOrder(Map<String, dynamic> data) => dio.post('/sales-orders', data: data);
  Future<Response> updateSalesOrder(String id, Map<String, dynamic> data) => dio.patch('/sales-orders/$id', data: data);

  // ── HR ────────────────────────────────────────────────────────
  Future<Response> getEmployees({int page = 1}) =>
      dio.get('/hr/employees', queryParameters: {'page': page, 'limit': 25});
  Future<Response> getEmployeeDetail(String id) => dio.get('/hr/employees/$id');
  Future<Response> createEmployee(Map<String, dynamic> data) => dio.post('/hr/employees', data: data);
  Future<Response> updateEmployee(String id, Map<String, dynamic> data) => dio.patch('/hr/employees/$id', data: data);
  Future<Response> getAttendance({String? employeeId, String? month}) => dio.get('/hr/attendance', queryParameters: {if (employeeId != null) 'employeeId': employeeId, if (month != null) 'month': month});
  Future<Response> createAttendance(Map<String, dynamic> data) => dio.post('/hr/attendance', data: data);
  Future<Response> getPayroll({String? month}) => dio.get('/hr/payroll', queryParameters: {if (month != null) 'month': month});
  Future<Response> createPayroll(Map<String, dynamic> data) => dio.post('/hr/payroll', data: data);
  Future<Response> getLeaves({String? employeeId, String? status}) => dio.get('/hr/leaves', queryParameters: {if (employeeId != null) 'employeeId': employeeId, if (status != null) 'status': status});
  Future<Response> createLeave(Map<String, dynamic> data) => dio.post('/hr/leaves', data: data);
  Future<Response> updateLeave(String id, Map<String, dynamic> data) => dio.patch('/hr/leaves/$id', data: data);
  Future<Response> getHrSummary() => dio.get('/hr/summary');

  // ── Support ───────────────────────────────────────────────────
  Future<Response> getTickets({int page = 1, String status = ''}) =>
      dio.get('/support/tickets', queryParameters: {
        'page': page, 'limit': 25,
        if (status.isNotEmpty) 'status': status,
      });
  Future<Response> getTicketDetail(String id) => dio.get('/support/tickets/$id');
  Future<Response> createTicket(Map<String, dynamic> data) => dio.post('/support/tickets', data: data);
  Future<Response> updateTicket(String id, Map<String, dynamic> data) => dio.patch('/support/tickets/$id', data: data);
  // ── Projects ──────────────────────────────────────────────────
  Future<Response> getProjects({int page = 1}) => dio.get('/projects', queryParameters: {'page': page, 'limit': 25});
  Future<Response> getProjectDetail(String id) => dio.get('/projects/$id');
  Future<Response> createProject(Map<String, dynamic> data) => dio.post('/projects', data: data);
  Future<Response> updateProject(String id, Map<String, dynamic> data) => dio.patch('/projects/$id', data: data);
  Future<Response> deleteProject(String id) => dio.delete('/projects/$id');
  Future<Response> getProjectTasks(String projectId) => dio.get('/projects/$projectId/tasks');
  Future<Response> getTasks({String? projectId, String? status}) => dio.get('/projects/tasks', queryParameters: {if (projectId != null) 'projectId': projectId, if (status != null) 'status': status});
  Future<Response> createTask(Map<String, dynamic> data) => dio.post('/projects/tasks', data: data);
  Future<Response> updateTask(String id, Map<String, dynamic> data) => dio.patch('/projects/tasks/$id', data: data);
  Future<Response> deleteTask(String id) => dio.delete('/projects/tasks/$id');
  // ── Deals ─────────────────────────────────────────────────────
  Future<Response> getDeals({int page = 1, String stage = ''}) => dio.get('/deals', queryParameters: {'page': page, 'limit': 25, if (stage.isNotEmpty) 'stage': stage});
  Future<Response> getDealDetail(String id) => dio.get('/deals/$id');
  Future<Response> createDeal(Map<String, dynamic> data) => dio.post('/deals', data: data);
  Future<Response> updateDeal(String id, Map<String, dynamic> data) => dio.patch('/deals/$id', data: data);
  Future<Response> deleteDeal(String id) => dio.delete('/deals/$id');

  // ── Party Contacts ────────────────────────────────────────────
  Future<Response> getPartyContacts(String partyId) => dio.get('/parties/$partyId/contacts');
  Future<Response> createPartyContact(String partyId, Map<String, dynamic> data) => dio.post('/parties/$partyId/contacts', data: data);
  Future<Response> updatePartyContact(String partyId, String contactId, Map<String, dynamic> data) => dio.patch('/parties/$partyId/contacts/$contactId', data: data);
  Future<Response> deletePartyContact(String partyId, String contactId) => dio.delete('/parties/$partyId/contacts/$contactId');

  // ── Activities ────────────────────────────────────────────────
  Future<Response> getActivities({int page = 1, String type = ''}) =>
      dio.get('/org-admin/activity', queryParameters: {
        'page': page, 'limit': 25,
        if (type.isNotEmpty) 'type': type,
      });
  Future<Response> createActivity(Map<String, dynamic> data) => dio.post('/activities', data: data);

  // ── Appointments ──────────────────────────────────────────────
  Future<Response> getAppointments({String? date, String? status}) =>
      dio.get('/appointments', queryParameters: {
        if (date   != null) 'date':   date,
        if (status != null) 'status': status,
      });
  Future<Response> createAppointment(Map<String, dynamic> data) => dio.post('/appointments', data: data);
  Future<Response> updateAppointment(String id, Map<String, dynamic> data) => dio.patch('/appointments/$id', data: data);
  Future<Response> deleteAppointment(String id) => dio.delete('/appointments/$id');

  // ── Notifications ─────────────────────────────────────────────
  Future<Response> getNotifications() => dio.get('/notifications');
  Future<Response> markNotificationRead(String id) => dio.patch('/notifications/$id/read');
  Future<Response> markAllNotificationsRead() => dio.patch('/notifications/read-all');

  // ── Avatar upload ─────────────────────────────────────────────
  Future<Response> uploadAvatar(FormData formData) => dio.post('/auth/avatar', data: formData);

  // ── Module management ─────────────────────────────────────────
  Future<Response> updateModules(List<String> enabledModules) =>
      dio.patch('/organizations/current/modules', data: {'enabledModules': enabledModules});

  // ── GST ───────────────────────────────────────────────────────
  Future<Response> getGstReturns({String? type, String? period}) =>
      dio.get('/gst/returns', queryParameters: {
        if (type   != null) 'type':   type,
        if (period != null) 'period': period,
      });
  Future<Response> fileGstReturn(String returnType, String period) =>
      dio.post('/gst/file/$returnType', data: {'period': period});

  // ── Reports ───────────────────────────────────────────────────
  Future<Response> getSalesReport({String? from, String? to}) =>
      dio.get('/reports/sales', queryParameters: {
        if (from != null) 'from': from,
        if (to   != null) 'to':   to,
      });
  Future<Response> getFinanceReport({String? from, String? to}) =>
      dio.get('/reports/finance', queryParameters: {
        if (from != null) 'from': from,
        if (to   != null) 'to':   to,
      });
  Future<Response> getCrmReport({String? from, String? to}) =>
      dio.get('/reports/crm', queryParameters: {
        if (from != null) 'from': from,
        if (to   != null) 'to':   to,
      });
  Future<Response> getInventoryReport({String? from, String? to}) =>
      dio.get('/reports/inventory', queryParameters: {
        if (from != null) 'from': from,
        if (to   != null) 'to':   to,
      });

  // ── Quotations ────────────────────────────────────────────────
  Future<Response> getQuotations({String? status}) =>
      dio.get('/quotations', queryParameters: {if (status != null && status != 'ALL') 'status': status});
  Future<Response> getQuotationDetail(String id) => dio.get('/quotations/$id');
  Future<Response> createQuotation(Map<String, dynamic> data) => dio.post('/quotations', data: data);
  Future<Response> updateQuotation(String id, Map<String, dynamic> data) => dio.patch('/quotations/$id', data: data);
  Future<Response> deleteQuotation(String id) => dio.delete('/quotations/$id');
  Future<Response> sendQuotation(String id) => dio.post('/quotations/$id/send');

  // ── Automations ───────────────────────────────────────────────
  Future<Response> createAutomation(Map<String, dynamic> data) => dio.post('/automations', data: data);
  Future<Response> deleteAutomation(String id) => dio.delete('/automations/$id');
  Future<Response> createAutomationFromTemplate(String templateName, Map<String, dynamic> data) =>
      dio.post('/automations/from-template', data: {'template': templateName, ...data});
  Future<Response> getAutomationLogs({String? automationId}) =>
      dio.get('/automations/logs', queryParameters: {if (automationId != null) 'automationId': automationId});

  // ── Import / Export (Trade) ───────────────────────────────────
  Future<Response> getShipments({String? type, String? status}) =>
      dio.get('/shipments', queryParameters: {
        if (type   != null) 'type':   type,
        if (status != null) 'status': status,
      });
  Future<Response> createShipment(Map<String, dynamic> data) => dio.post('/shipments', data: data);
  Future<Response> updateShipment(String id, Map<String, dynamic> data) => dio.patch('/shipments/$id', data: data);

  // ── Restaurant ────────────────────────────────────────────────
  Future<Response> getRestaurantTables() => dio.get('/restaurant/tables');
  Future<Response> getRestaurantOrders({String? status}) =>
      dio.get('/restaurant/orders', queryParameters: {if (status != null) 'status': status});
  Future<Response> createRestaurantOrder(Map<String, dynamic> data) => dio.post('/restaurant/orders', data: data);
  Future<Response> updateRestaurantOrder(String id, Map<String, dynamic> data) => dio.patch('/restaurant/orders/$id', data: data);
  Future<Response> settleRestaurantBill(String orderId, Map<String, dynamic> data) =>
      dio.post('/restaurant/orders/$orderId/settle', data: data);

  // ── Hotel ─────────────────────────────────────────────────────
  Future<Response> getHotelRooms({String? status}) =>
      dio.get('/hotel/rooms', queryParameters: {if (status != null) 'status': status});
  Future<Response> getHotelBookings({String? status}) =>
      dio.get('/hotel/bookings', queryParameters: {if (status != null) 'status': status});
  Future<Response> createHotelBooking(Map<String, dynamic> data) => dio.post('/hotel/bookings', data: data);
  Future<Response> updateHotelBooking(String id, Map<String, dynamic> data) => dio.patch('/hotel/bookings/$id', data: data);
  Future<Response> checkInGuest(String bookingId) => dio.post('/hotel/bookings/$bookingId/check-in');
  Future<Response> checkOutGuest(String bookingId, Map<String, dynamic> data) =>
      dio.post('/hotel/bookings/$bookingId/check-out', data: data);

  // ── Health & Clinic ───────────────────────────────────────────
  Future<Response> getPatients({String? search}) =>
      dio.get('/health/patients', queryParameters: {if (search != null && search.isNotEmpty) 'search': search});
  Future<Response> createPatient(Map<String, dynamic> data) => dio.post('/health/patients', data: data);
  Future<Response> getAppointmentsByDate(String date) => dio.get('/health/appointments', queryParameters: {'date': date});
  Future<Response> createHealthAppointment(Map<String, dynamic> data) => dio.post('/health/appointments', data: data);
  Future<Response> updateHealthAppointment(String id, Map<String, dynamic> data) => dio.patch('/health/appointments/$id', data: data);

  // ── Telecalling ───────────────────────────────────────────────
  Future<Response> getTelecallingCalls({String? status}) =>
      dio.get('/telecalling/calls', queryParameters: {if (status != null) 'status': status});
  Future<Response> logTelecallingCall(Map<String, dynamic> data) => dio.post('/telecalling/calls', data: data);
  Future<Response> getTelecallingCampaigns() => dio.get('/telecalling/campaigns');
  Future<Response> createTelecallingCampaign(Map<String, dynamic> data) => dio.post('/telecalling/campaigns', data: data);

  // ── Services (AMC / Job Cards) ────────────────────────────────
  Future<Response> getServiceJobs({String? status}) =>
      dio.get('/services/jobs', queryParameters: {if (status != null) 'status': status});
  Future<Response> createServiceJob(Map<String, dynamic> data) => dio.post('/services/jobs', data: data);
  Future<Response> updateServiceJob(String id, Map<String, dynamic> data) => dio.patch('/services/jobs/$id', data: data);
  Future<Response> getAmcContracts() => dio.get('/services/amc');
  Future<Response> createAmcContract(Map<String, dynamic> data) => dio.post('/services/amc', data: data);

  // ── Stock Market ──────────────────────────────────────────────
  Future<Response> getStockCalls({String? type}) =>
      dio.get('/stock-market/calls', queryParameters: {if (type != null) 'type': type});
  Future<Response> createStockCall(Map<String, dynamic> data) => dio.post('/stock-market/calls', data: data);
  Future<Response> getStockPortfolio() => dio.get('/stock-market/portfolio');
  Future<Response> addStockTrade(Map<String, dynamic> data) => dio.post('/stock-market/trades', data: data);

  // ── Lead Forms ────────────────────────────────────────────────
  Future<Response> getLeadForms() => dio.get('/lead-forms');
  Future<Response> createLeadForm(Map<String, dynamic> data) => dio.post('/lead-forms', data: data);
  Future<Response> updateLeadForm(String id, Map<String, dynamic> data) => dio.patch('/lead-forms/$id', data: data);
  Future<Response> deleteLeadForm(String id) => dio.delete('/lead-forms/$id');
  Future<Response> getLeadFormResponses(String formId) => dio.get('/lead-forms/$formId/responses');
  Future<Response> publishLeadForm(String id, bool publish) => dio.patch('/lead-forms/$id/publish', data: {'published': publish});

  // ── Documents ─────────────────────────────────────────────────
  Future<Response> getDocuments({String? folder}) =>
      dio.get('/documents', queryParameters: {if (folder != null) 'folder': folder});
  Future<Response> uploadDocument(FormData formData) => dio.post('/documents/upload', data: formData);
  Future<Response> deleteDocument(String id) => dio.delete('/documents/$id');
  Future<Response> getDocumentUrl(String id) => dio.get('/documents/$id/url');
  Future<Response> getDocumentFolders() => dio.get('/documents/folders');
  Future<Response> createDocumentFolder(String name) => dio.post('/documents/folders', data: {'name': name});

  // ── WhatsApp ──────────────────────────────────────────────────
  Future<Response> getWhatsappCampaigns() => dio.get('/whatsapp/campaigns');
  Future<Response> createWhatsappCampaign(Map<String, dynamic> data) => dio.post('/whatsapp/campaigns', data: data);
  Future<Response> getWhatsappTemplates() => dio.get('/whatsapp/templates');
  Future<Response> createWhatsappTemplate(Map<String, dynamic> data) => dio.post('/whatsapp/templates', data: data);
  Future<Response> getWhatsappStats() => dio.get('/whatsapp/stats');

  // ── E-commerce ────────────────────────────────────────────────
  Future<Response> getEcommerceConnections() => dio.get('/ecommerce/connections');
  Future<Response> connectEcommercePlatform(String platform, Map<String, dynamic> data) =>
      dio.post('/ecommerce/connect/$platform', data: data);
  Future<Response> getEcommerceOrders({String? platform, String? status}) =>
      dio.get('/ecommerce/orders', queryParameters: {
        if (platform != null) 'platform': platform,
        if (status   != null) 'status':   status,
      });
  Future<Response> syncEcommerceOrders(String platform) => dio.post('/ecommerce/sync/$platform');
  Future<Response> getEcommerceSummary() => dio.get('/ecommerce/summary');

  // ── POS ───────────────────────────────────────────────────────
  Future<Response> getPosHistory({int page = 1}) =>
      dio.get('/pos/sales', queryParameters: {'page': page, 'limit': 25});
  Future<Response> getPosShiftSummary() => dio.get('/pos/shift-summary');
}
