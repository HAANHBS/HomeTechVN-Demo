export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

type Relationship = {
  foreignKeyName: string
  columns: string[]
  isOneToOne: boolean
  referencedRelation: string
  referencedColumns: string[]
}

type TableDef<Row, Insert, Update> = {
  Row: Row
  Insert: Insert
  Update: Update
  Relationships: Relationship[]
}

export type CustomerRow = {
  id: string
  customer_code: string
  full_name: string
  customer_type: string
  phone: string | null
  phone_normalized: string | null
  email: string | null
  zalo: string | null
  address: string | null
  tax_code: string | null
  birthday: string | null
  status: string
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type CustomerInsert = {
  id?: string
  customer_code?: string
  full_name: string
  customer_type?: string
  phone?: string | null
  phone_normalized?: string | null
  email?: string | null
  zalo?: string | null
  address?: string | null
  tax_code?: string | null
  birthday?: string | null
  status?: string
  created_by?: string | null
  updated_by?: string | null
  created_at?: string
  updated_at?: string
}

export type CustomerUpdate = Partial<CustomerInsert>

export type DeviceRow = {
  id: string
  device_code: string
  customer_id: string
  device_type: string
  brand: string | null
  model: string | null
  serial_number: string | null
  asset_tag: string | null
  color: string | null
  condition_notes: string | null
  purchase_date: string | null
  status: string
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type DeviceInsert = {
  id?: string
  device_code?: string
  customer_id: string
  device_type: string
  brand?: string | null
  model?: string | null
  serial_number?: string | null
  asset_tag?: string | null
  color?: string | null
  condition_notes?: string | null
  purchase_date?: string | null
  status?: string
  created_by?: string | null
  updated_by?: string | null
  created_at?: string
  updated_at?: string
}

export type DeviceUpdate = Partial<DeviceInsert>

export type NoteRow = {
  id: string
  customer_id: string
  note_type: string
  content: string
  is_pinned: boolean
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type NoteInsert = {
  id?: string
  customer_id: string
  note_type?: string
  content: string
  is_pinned?: boolean
  created_by?: string | null
  updated_by?: string | null
  created_at?: string
  updated_at?: string
}

export type NoteUpdate = Partial<NoteInsert>


export type ProductCategoryRow = {
  id: string
  name: string
  description: string | null
  sort_order: number
  is_active: boolean
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ProductCategoryInsert = {
  id?: string
  name: string
  description?: string | null
  sort_order?: number
  is_active?: boolean
  created_by?: string | null
  updated_by?: string | null
  created_at?: string
  updated_at?: string
}

export type ProductCategoryUpdate = Partial<ProductCategoryInsert>

export type ProductRow = {
  id: string
  sku: string
  name: string
  category_id: string | null
  brand: string | null
  model: string | null
  barcode: string | null
  unit: string
  description: string | null
  sale_price: number
  min_stock: number
  track_serial: boolean
  warranty_months: number
  is_active: boolean
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ProductInsert = {
  id?: string
  sku: string
  name: string
  category_id?: string | null
  brand?: string | null
  model?: string | null
  barcode?: string | null
  unit?: string
  description?: string | null
  sale_price?: number
  min_stock?: number
  track_serial?: boolean
  warranty_months?: number
  is_active?: boolean
  created_by?: string | null
  updated_by?: string | null
  created_at?: string
  updated_at?: string
}

export type ProductUpdate = Partial<ProductInsert>

export type InventoryUnitRow = {
  id: string
  product_id: string
  serial_number: string
  asset_tag: string | null
  status: string
  location: string | null
  received_at: string
  issued_at: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type InventoryTransactionRow = {
  id: string
  product_id: string
  inventory_unit_id: string | null
  transaction_type: string
  quantity: number
  reference_type: string | null
  reference_id: string | null
  note: string | null
  occurred_at: string
  created_by: string | null
  created_at: string
}

export type InventoryTransactionViewRow = InventoryTransactionRow & {
  unit_cost: number | null
}

export type ProductInventorySummaryRow = {
  product_id: string | null
  sku: string | null
  name: string | null
  category_id: string | null
  brand: string | null
  model: string | null
  unit: string | null
  sale_price: number | null
  min_stock: number | null
  track_serial: boolean | null
  is_active: boolean | null
  stock_qty: number | null
  low_stock: boolean | null
  last_unit_cost: number | null
}


export type SalesChecklistItem = {
  key: string
  label: string
  required: boolean
  checked: boolean
  checked_at?: string | null
  checked_by?: string | null
}

export type SalesOrderRow = {
  id: string
  order_code: string
  customer_id: string
  status: string
  subtotal: number
  discount_amount: number
  total_amount: number
  paid_amount: number
  balance_due: number | null
  note: string | null
  checklist: Json
  stock_issued_at: string | null
  confirmed_at: string | null
  payment_pending_at: string | null
  paid_at: string | null
  delivered_at: string | null
  completed_at: string | null
  cancelled_at: string | null
  cancelled_reason: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type SalesOrderItemRow = {
  id: string
  sales_order_id: string
  product_id: string
  sku_snapshot: string
  product_name_snapshot: string
  quantity: number
  unit_price: number
  discount_amount: number
  line_total: number | null
  warranty_months: number
  inventory_unit_ids: string[]
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type PaymentRow = {
  id: string
  payment_code: string
  sales_order_id: string
  amount: number
  payment_method: string
  status: string
  reference_no: string | null
  note: string | null
  paid_at: string
  refunded_at: string | null
  refund_note: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type SalesOrderSummaryRow = {
  id: string | null
  order_code: string | null
  customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  phone: string | null
  status: string | null
  subtotal: number | null
  discount_amount: number | null
  total_amount: number | null
  paid_amount: number | null
  balance_due: number | null
  stock_issued_at: string | null
  confirmed_at: string | null
  paid_at: string | null
  delivered_at: string | null
  completed_at: string | null
  cancelled_at: string | null
  created_at: string | null
  updated_at: string | null
  item_count: number | null
  required_checklist_count: number | null
  required_checked_count: number | null
}


export type RepairOrderRow = {
  id: string
  repair_code: string
  customer_id: string
  customer_device_id: string
  status: string
  priority: string
  reported_issue: string
  intake_condition: string | null
  accessories_received: string[]
  customer_request: string | null
  intake_note: string | null
  assigned_technician_id: string | null
  approved_quote_id: string | null
  approved_amount: number
  final_amount: number
  estimated_completion_at: string | null
  waiting_part_note: string | null
  customer_rejected_reason: string | null
  no_fix_reason: string | null
  warranty_transfer_note: string | null
  qc_passed: boolean | null
  qc_note: string | null
  diagnosed_at: string | null
  quoted_at: string | null
  awaiting_customer_at: string | null
  approved_at: string | null
  repairing_at: string | null
  qc_at: string | null
  ready_at: string | null
  returned_at: string | null
  completed_at: string | null
  cancelled_at: string | null
  warranty_transfer_at: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type RepairDiagnosticRow = {
  id: string
  repair_order_id: string
  stage: string
  symptom: string | null
  findings: string
  conclusion: string | null
  recommendation: string | null
  passed: boolean | null
  created_by: string | null
  created_at: string
}

export type RepairQuoteRow = {
  id: string
  repair_order_id: string
  version: number
  status: string
  labor_amount: number
  parts_amount: number
  discount_amount: number
  total_amount: number | null
  valid_until: string | null
  note: string | null
  customer_response_note: string | null
  sent_at: string | null
  approved_at: string | null
  rejected_at: string | null
  created_by: string | null
  created_at: string
}

export type RepairPartRow = {
  id: string
  repair_order_id: string
  product_id: string
  quantity: number
  unit_price: number
  line_total: number | null
  inventory_unit_ids: string[]
  status: string
  note: string | null
  issued_at: string | null
  returned_at: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type RepairStatusHistoryRow = {
  id: number
  repair_order_id: string
  from_status: string | null
  to_status: string
  note: string | null
  changed_by: string | null
  changed_at: string
}

export type RepairOrderSummaryRow = {
  id: string | null
  repair_code: string | null
  customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  phone: string | null
  customer_device_id: string | null
  device_code: string | null
  device_type: string | null
  brand: string | null
  model: string | null
  serial_number: string | null
  status: string | null
  priority: string | null
  reported_issue: string | null
  assigned_technician_id: string | null
  approved_amount: number | null
  final_amount: number | null
  estimated_completion_at: string | null
  created_at: string | null
  updated_at: string | null
  ready_at: string | null
  completed_at: string | null
  diagnosis_count: number | null
  issued_part_count: number | null
  latest_quote_status: string | null
  latest_quote_total: number | null
}


export type ChecklistTemplateRow = {
  id: string
  template_code: string
  version: number
  name: string
  module: string
  entity_type: string
  description: string | null
  is_active: boolean
  is_system: boolean
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ChecklistTemplateItemRow = {
  id: string
  template_id: string
  item_key: string
  label: string
  description: string | null
  sort_order: number
  requirement_rule: string
  system_managed: boolean
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ChecklistRunRow = {
  id: string
  template_id: string
  template_code_snapshot: string
  template_version: number
  entity_type: string
  entity_id: string
  status: string
  note: string | null
  started_by: string | null
  completed_by: string | null
  cancelled_by: string | null
  started_at: string
  completed_at: string | null
  cancelled_at: string | null
  created_at: string
  updated_at: string
}

export type ChecklistRunItemRow = {
  id: string
  run_id: string
  template_item_id: string | null
  item_key: string
  label: string
  description: string | null
  sort_order: number
  required: boolean
  system_managed: boolean
  checked: boolean
  note: string | null
  checked_by: string | null
  checked_at: string | null
  created_at: string
  updated_at: string
}

export type ChecklistRunSummaryRow = {
  id: string | null
  template_id: string | null
  template_code_snapshot: string | null
  template_version: number | null
  template_name: string | null
  module: string | null
  entity_type: string | null
  entity_id: string | null
  status: string | null
  note: string | null
  started_by: string | null
  completed_by: string | null
  cancelled_by: string | null
  started_at: string | null
  completed_at: string | null
  cancelled_at: string | null
  created_at: string | null
  updated_at: string | null
  item_count: number | null
  required_count: number | null
  required_checked_count: number | null
  checked_count: number | null
}

export type WarrantyRow = {
  id: string
  warranty_code: string
  lookup_token: string
  customer_id: string
  customer_device_id: string | null
  source_type: string
  source_id: string
  source_item_id: string | null
  product_id: string | null
  inventory_unit_id: string | null
  product_name_snapshot: string | null
  serial_snapshot: string | null
  coverage: string
  start_date: string
  end_date: string
  status: string
  void_reason: string | null
  note: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type WarrantyClaimRow = {
  id: string
  claim_code: string
  warranty_id: string
  status: string
  issue_description: string
  intake_condition: string | null
  customer_request: string | null
  assigned_technician_id: string | null
  decision_note: string | null
  service_note: string | null
  resolution: string | null
  qc_passed: boolean | null
  qc_note: string | null
  received_at: string
  checking_at: string | null
  approved_at: string | null
  rejected_at: string | null
  in_service_at: string | null
  qc_at: string | null
  ready_at: string | null
  returned_at: string | null
  closed_at: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type WarrantyStatusHistoryRow = {
  id: number
  warranty_claim_id: string
  from_status: string | null
  to_status: string
  note: string | null
  changed_by: string | null
  changed_at: string
}

export type WarrantySummaryRow = {
  id: string | null
  warranty_code: string | null
  lookup_token: string | null
  customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  phone: string | null
  customer_device_id: string | null
  device_code: string | null
  device_type: string | null
  brand: string | null
  model: string | null
  device_serial: string | null
  source_type: string | null
  source_id: string | null
  source_item_id: string | null
  product_id: string | null
  inventory_unit_id: string | null
  product_name_snapshot: string | null
  serial_snapshot: string | null
  coverage: string | null
  start_date: string | null
  end_date: string | null
  status: string | null
  effective_status: string | null
  void_reason: string | null
  note: string | null
  created_at: string | null
  updated_at: string | null
  claim_count: number | null
  latest_claim_status: string | null
}

export type WarrantyClaimSummaryRow = {
  id: string | null
  claim_code: string | null
  warranty_id: string | null
  warranty_code: string | null
  customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  phone: string | null
  customer_device_id: string | null
  device_code: string | null
  device_type: string | null
  brand: string | null
  model: string | null
  status: string | null
  issue_description: string | null
  assigned_technician_id: string | null
  qc_passed: boolean | null
  received_at: string | null
  ready_at: string | null
  returned_at: string | null
  closed_at: string | null
  created_at: string | null
  updated_at: string | null
}


export type ServiceRow = {
  id: string
  name: string
  category: string
  description: string | null
  default_interval_count: number
  default_interval_unit: string
  default_price: number
  warranty_months: number
  is_active: boolean
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ServiceScheduleRow = {
  id: string
  service_id: string
  customer_id: string
  customer_device_id: string | null
  status: string
  interval_count: number
  interval_unit: string
  start_date: string
  next_due_date: string
  end_date: string | null
  price: number
  completion_count: number
  last_completed_at: string | null
  last_completion_id: string | null
  note: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type SoftwareProductRow = {
  id: string
  category: string
  vendor: string | null
  name: string
  edition: string | null
  billing_model: string
  default_term_months: number | null
  description: string | null
  is_active: boolean
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type SoftwareLicenseRow = {
  id: string
  license_code: string
  software_product_id: string
  customer_id: string
  customer_device_id: string | null
  status: string
  start_date: string
  end_date: string | null
  seats: number
  account_identifier: string | null
  secret_ref: string | null
  auto_renew: boolean
  renewal_cost: number
  note: string | null
  cancelled_reason: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ServiceScheduleSummaryRow = {
  id: string | null
  service_id: string | null
  service_name: string | null
  category: string | null
  customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  phone: string | null
  customer_device_id: string | null
  device_code: string | null
  device_type: string | null
  device_brand: string | null
  device_model: string | null
  status: string | null
  interval_count: number | null
  interval_unit: string | null
  start_date: string | null
  next_due_date: string | null
  end_date: string | null
  price: number | null
  completion_count: number | null
  last_completed_at: string | null
  last_completion_id: string | null
  note: string | null
  created_at: string | null
  updated_at: string | null
}

export type SoftwareLicenseSummaryRow = {
  id: string | null
  license_code: string | null
  software_product_id: string | null
  category: string | null
  vendor: string | null
  product_name: string | null
  edition: string | null
  billing_model: string | null
  customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  phone: string | null
  customer_device_id: string | null
  device_code: string | null
  device_type: string | null
  device_brand: string | null
  device_model: string | null
  status: string | null
  start_date: string | null
  end_date: string | null
  seats: number | null
  account_identifier: string | null
  secret_ref: string | null
  auto_renew: boolean | null
  renewal_cost: number | null
  note: string | null
  cancelled_reason: string | null
  created_at: string | null
  updated_at: string | null
}


export type ReminderRuleRow = {
  id: string
  rule_code: string
  name: string
  event_type: string
  offset_minutes: number
  priority: string
  is_active: boolean
  is_system: boolean
  description: string | null
  staff_channels: string[]
  customer_channels: string[]
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ReminderRow = {
  id: string
  reminder_code: string
  rule_id: string
  rule_code_snapshot: string
  event_type: string
  source_type: string
  source_id: string
  source_label: string | null
  customer_id: string | null
  anchor_at: string | null
  due_at: string
  priority: string
  status: string
  title: string
  message: string
  dedupe_key: string
  metadata: Json
  generated_by: string
  first_seen_at: string
  last_seen_at: string
  last_seen_run_id: string | null
  snoozed_until: string | null
  acknowledged_by: string | null
  acknowledged_at: string | null
  resolved_at: string | null
  resolution_reason: string | null
  operator_note: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ReminderSummaryRow = {
  id: string | null
  reminder_code: string | null
  rule_id: string | null
  rule_code_snapshot: string | null
  event_type: string | null
  source_type: string | null
  source_id: string | null
  source_label: string | null
  customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  phone: string | null
  anchor_at: string | null
  due_at: string | null
  priority: string | null
  status: string | null
  title: string | null
  message: string | null
  metadata: Json | null
  generated_by: string | null
  first_seen_at: string | null
  last_seen_at: string | null
  snoozed_until: string | null
  acknowledged_by: string | null
  acknowledged_at: string | null
  resolved_at: string | null
  resolution_reason: string | null
  operator_note: string | null
  created_at: string | null
  updated_at: string | null
}


export type NotificationRow = {
  id: string
  notification_code: string
  reminder_id: string
  channel: string
  provider: string
  audience: string
  recipient_profile_id: string | null
  recipient_customer_id: string | null
  recipient_address: string | null
  template_key: string | null
  subject: string | null
  body: string
  payload: Json
  status: string
  scheduled_at: string
  next_attempt_at: string
  attempt_count: number
  max_attempts: number
  last_attempt_at: string | null
  sent_at: string | null
  read_at: string | null
  external_message_id: string | null
  last_error_code: string | null
  last_error_message: string | null
  delivery_key: string
  created_at: string
  updated_at: string
}

export type NotificationLogRow = {
  id: number
  notification_id: string
  attempt_no: number
  channel: string
  provider: string
  status: string
  request_meta: Json
  response_meta: Json
  external_message_id: string | null
  error_code: string | null
  error_message: string | null
  started_at: string
  finished_at: string | null
}

export type NotificationSummaryRow = {
  id: string | null
  notification_code: string | null
  reminder_id: string | null
  reminder_code: string | null
  rule_code_snapshot: string | null
  event_type: string | null
  channel: string | null
  provider: string | null
  audience: string | null
  recipient_profile_id: string | null
  recipient_profile_name: string | null
  recipient_customer_id: string | null
  customer_code: string | null
  customer_name: string | null
  recipient_address: string | null
  template_key: string | null
  subject: string | null
  body: string | null
  payload: Json | null
  status: string | null
  scheduled_at: string | null
  next_attempt_at: string | null
  attempt_count: number | null
  max_attempts: number | null
  last_attempt_at: string | null
  sent_at: string | null
  read_at: string | null
  external_message_id: string | null
  last_error_code: string | null
  last_error_message: string | null
  created_at: string | null
  updated_at: string | null
}

export type Database = {
  __InternalSupabase: {
    PostgrestVersion: '14.5'
  }
  public: {
    Tables: {
      customers: TableDef<CustomerRow, CustomerInsert, CustomerUpdate>
      customer_devices: TableDef<DeviceRow, DeviceInsert, DeviceUpdate>
      customer_notes: TableDef<NoteRow, NoteInsert, NoteUpdate>
      product_categories: TableDef<ProductCategoryRow, ProductCategoryInsert, ProductCategoryUpdate>
      products: TableDef<ProductRow, ProductInsert, ProductUpdate>
      inventory_units: TableDef<
        InventoryUnitRow,
        {
          id?: string
          product_id: string
          serial_number: string
          asset_tag?: string | null
          status?: string
          location?: string | null
          received_at?: string
          issued_at?: string | null
          created_by?: string | null
          updated_by?: string | null
          created_at?: string
          updated_at?: string
        },
        Partial<InventoryUnitRow>
      >
      inventory_transactions: TableDef<
        InventoryTransactionRow,
        {
          id?: string
          product_id: string
          inventory_unit_id?: string | null
          transaction_type: string
          quantity: number
          reference_type?: string | null
          reference_id?: string | null
          note?: string | null
          occurred_at?: string
          created_by?: string | null
          created_at?: string
        },
        Partial<InventoryTransactionRow>
      >
      sales_orders: TableDef<
        SalesOrderRow,
        Partial<SalesOrderRow> & { customer_id: string },
        Partial<SalesOrderRow>
      >
      sales_order_items: TableDef<
        SalesOrderItemRow,
        Partial<SalesOrderItemRow> & {
          sales_order_id: string
          product_id: string
          sku_snapshot: string
          product_name_snapshot: string
          quantity: number
          unit_price: number
        },
        Partial<SalesOrderItemRow>
      >
      payments: TableDef<
        PaymentRow,
        Partial<PaymentRow> & {
          sales_order_id: string
          amount: number
          payment_method: string
        },
        Partial<PaymentRow>
      >
      repair_orders: TableDef<
        RepairOrderRow,
        Partial<RepairOrderRow> & { customer_id: string; customer_device_id: string; reported_issue: string },
        Partial<RepairOrderRow>
      >
      repair_diagnostics: TableDef<
        RepairDiagnosticRow,
        Partial<RepairDiagnosticRow> & { repair_order_id: string; stage: string; findings: string },
        Partial<RepairDiagnosticRow>
      >
      repair_quotes: TableDef<
        RepairQuoteRow,
        Partial<RepairQuoteRow> & { repair_order_id: string; version: number },
        Partial<RepairQuoteRow>
      >
      repair_parts: TableDef<
        RepairPartRow,
        Partial<RepairPartRow> & { repair_order_id: string; product_id: string; quantity: number },
        Partial<RepairPartRow>
      >
      repair_status_history: TableDef<
        RepairStatusHistoryRow,
        Partial<RepairStatusHistoryRow> & { repair_order_id: string; to_status: string },
        Partial<RepairStatusHistoryRow>
      >
      checklist_templates: TableDef<
        ChecklistTemplateRow,
        Partial<ChecklistTemplateRow> & {
          template_code: string
          version: number
          name: string
          module: string
          entity_type: string
        },
        Partial<ChecklistTemplateRow>
      >
      checklist_template_items: TableDef<
        ChecklistTemplateItemRow,
        Partial<ChecklistTemplateItemRow> & {
          template_id: string
          item_key: string
          label: string
          sort_order: number
        },
        Partial<ChecklistTemplateItemRow>
      >
      checklist_runs: TableDef<
        ChecklistRunRow,
        Partial<ChecklistRunRow> & {
          template_id: string
          template_code_snapshot: string
          template_version: number
          entity_type: string
          entity_id: string
        },
        Partial<ChecklistRunRow>
      >
      checklist_run_items: TableDef<
        ChecklistRunItemRow,
        Partial<ChecklistRunItemRow> & {
          run_id: string
          item_key: string
          label: string
          sort_order: number
        },
        Partial<ChecklistRunItemRow>
      >
      warranties: TableDef<
        WarrantyRow,
        Partial<WarrantyRow> & { customer_id: string; source_type: string; source_id: string; coverage: string; start_date: string; end_date: string },
        Partial<WarrantyRow>
      >
      warranty_claims: TableDef<
        WarrantyClaimRow,
        Partial<WarrantyClaimRow> & { warranty_id: string; issue_description: string },
        Partial<WarrantyClaimRow>
      >
      warranty_status_history: TableDef<
        WarrantyStatusHistoryRow,
        Partial<WarrantyStatusHistoryRow> & { warranty_claim_id: string; to_status: string },
        Partial<WarrantyStatusHistoryRow>
      >
      services: TableDef<
        ServiceRow,
        Partial<ServiceRow> & { name: string },
        Partial<ServiceRow>
      >
      service_schedules: TableDef<
        ServiceScheduleRow,
        Partial<ServiceScheduleRow> & {
          service_id: string
          customer_id: string
          interval_count: number
          interval_unit: string
          start_date: string
          next_due_date: string
        },
        Partial<ServiceScheduleRow>
      >
      software_products: TableDef<
        SoftwareProductRow,
        Partial<SoftwareProductRow> & {
          category: string
          name: string
        },
        Partial<SoftwareProductRow>
      >
      software_licenses: TableDef<
        SoftwareLicenseRow,
        Partial<SoftwareLicenseRow> & {
          software_product_id: string
          customer_id: string
          start_date: string
        },
        Partial<SoftwareLicenseRow>
      >
      reminder_rules: TableDef<
        ReminderRuleRow,
        Partial<ReminderRuleRow> & {
          rule_code: string
          name: string
          event_type: string
        },
        Partial<ReminderRuleRow>
      >
      reminders: TableDef<
        ReminderRow,
        Partial<ReminderRow> & {
          rule_id: string
          rule_code_snapshot: string
          event_type: string
          source_type: string
          source_id: string
          due_at: string
          priority: string
          title: string
          message: string
          dedupe_key: string
        },
        Partial<ReminderRow>
      >
      notifications: TableDef<
        NotificationRow,
        Partial<NotificationRow> & {
          reminder_id: string
          channel: string
          provider: string
          audience: string
          body: string
          delivery_key: string
        },
        Partial<NotificationRow>
      >
      notification_logs: TableDef<
        NotificationLogRow,
        Partial<NotificationLogRow> & {
          notification_id: string
          attempt_no: number
          channel: string
          provider: string
          status: string
        },
        Partial<NotificationLogRow>
      >
      settings: TableDef<
        {
          key: string
          value: Json | null
          description: string | null
          is_sensitive: boolean
          secret_ref: string | null
          updated_by: string | null
          created_at: string
          updated_at: string
        },
        {
          key: string
          value?: Json | null
          description?: string | null
          is_sensitive?: boolean
          secret_ref?: string | null
          updated_by?: string | null
          created_at?: string
          updated_at?: string
        },
        {
          key?: string
          value?: Json | null
          description?: string | null
          is_sensitive?: boolean
          secret_ref?: string | null
          updated_by?: string | null
          created_at?: string
          updated_at?: string
        }
      >
      profiles: TableDef<
        {
          id: string
          email: string | null
          full_name: string | null
          phone: string | null
          avatar_url: string | null
          role_id: string | null
          is_active: boolean
          last_login_at: string | null
          created_at: string
          updated_at: string
        },
        {
          id: string
          email?: string | null
          full_name?: string | null
          phone?: string | null
          avatar_url?: string | null
          role_id?: string | null
          is_active?: boolean
          last_login_at?: string | null
          created_at?: string
          updated_at?: string
        },
        Record<string, never>
      >
      roles: TableDef<
        {
          id: string
          code: string
          name: string
          description: string | null
          is_system: boolean
          is_active: boolean
          created_at: string
          updated_at: string
        },
        Record<string, never>,
        Record<string, never>
      >
      permissions: TableDef<
        {
          id: string
          code: string
          module: string
          name: string
          description: string | null
          created_at: string
        },
        Record<string, never>,
        Record<string, never>
      >
      role_permissions: TableDef<
        {
          role_id: string
          permission_id: string
          created_at: string
        },
        Record<string, never>,
        Record<string, never>
      >
    }
    Views: {
      inventory_transactions_view: {
        Row: InventoryTransactionViewRow
        Relationships: Relationship[]
      }
      product_inventory_summary: {
        Row: ProductInventorySummaryRow
        Relationships: Relationship[]
      }
      sales_order_summary: {
        Row: SalesOrderSummaryRow
        Relationships: Relationship[]
      }
      repair_order_summary: {
        Row: RepairOrderSummaryRow
        Relationships: Relationship[]
      }
      checklist_run_summary: {
        Row: ChecklistRunSummaryRow
        Relationships: Relationship[]
      }
      warranty_summary: {
        Row: WarrantySummaryRow
        Relationships: Relationship[]
      }
      warranty_claim_summary: {
        Row: WarrantyClaimSummaryRow
        Relationships: Relationship[]
      }
      service_schedule_summary: {
        Row: ServiceScheduleSummaryRow
        Relationships: Relationship[]
      }
      software_license_summary: {
        Row: SoftwareLicenseSummaryRow
        Relationships: Relationship[]
      }
      reminder_summary: {
        Row: ReminderSummaryRow
        Relationships: Relationship[]
      }
      notification_summary: {
        Row: NotificationSummaryRow
        Relationships: Relationship[]
      }
    }
    Functions: {
      inventory_receive: {
        Args: {
          p_product_id: string
          p_quantity: number
          p_unit_cost?: number
          p_serial_numbers?: string[]
          p_note?: string
          p_reference_type?: string
          p_reference_id?: string
          p_location?: string
        }
        Returns: Json
      }
      inventory_issue: {
        Args: {
          p_product_id: string
          p_quantity: number
          p_inventory_unit_ids?: string[]
          p_note?: string
          p_reference_type?: string
          p_reference_id?: string
        }
        Returns: Json
      }
      sale_create: {
        Args: { p_customer_id: string; p_note?: string }
        Returns: Json
      }
      sale_update_draft: {
        Args: {
          p_order_id: string
          p_customer_id: string
          p_discount_amount?: number
          p_note?: string
        }
        Returns: Json
      }
      sale_add_item: {
        Args: {
          p_order_id: string
          p_product_id: string
          p_quantity: number
          p_unit_price?: number
          p_discount_amount?: number
          p_inventory_unit_ids?: string[]
        }
        Returns: Json
      }
      sale_update_item: {
        Args: {
          p_item_id: string
          p_quantity: number
          p_unit_price: number
          p_discount_amount?: number
          p_inventory_unit_ids?: string[]
        }
        Returns: Json
      }
      sale_remove_item: {
        Args: { p_item_id: string }
        Returns: boolean
      }
      sale_set_checklist_item: {
        Args: { p_order_id: string; p_key: string; p_checked: boolean }
        Returns: Json
      }
      sale_confirm: {
        Args: { p_order_id: string }
        Returns: Json
      }
      sale_record_payment: {
        Args: {
          p_order_id: string
          p_amount: number
          p_payment_method: string
          p_reference_no?: string
          p_note?: string
        }
        Returns: Json
      }
      sale_refund_payment: {
        Args: { p_payment_id: string; p_refund_note: string }
        Returns: Json
      }
      sale_deliver: {
        Args: { p_order_id: string }
        Returns: Json
      }
      sale_complete: {
        Args: { p_order_id: string }
        Returns: Json
      }
      sale_cancel: {
        Args: { p_order_id: string; p_reason: string }
        Returns: Json
      }
      repair_create: {
        Args: {
          p_customer_id: string
          p_customer_device_id: string
          p_reported_issue: string
          p_intake_condition?: string
          p_accessories_received?: string[]
          p_customer_request?: string
          p_priority?: string
          p_intake_note?: string
        }
        Returns: Json
      }
      repair_start_diagnosis: { Args: { p_order_id: string }; Returns: Json }
      repair_add_diagnostic: {
        Args: { p_order_id: string; p_symptom: string; p_findings: string; p_conclusion?: string; p_recommendation?: string }
        Returns: Json
      }
      repair_create_quote: {
        Args: { p_order_id: string; p_labor_amount: number; p_parts_amount: number; p_discount_amount?: number; p_valid_until?: string; p_note?: string }
        Returns: Json
      }
      repair_submit_quote: { Args: { p_quote_id: string }; Returns: Json }
      repair_customer_decision: { Args: { p_order_id: string; p_approved: boolean; p_response_note?: string }; Returns: Json }
      repair_plan_part: {
        Args: { p_order_id: string; p_product_id: string; p_quantity: number; p_unit_price?: number; p_inventory_unit_ids?: string[]; p_note?: string }
        Returns: Json
      }
      repair_issue_part: { Args: { p_part_id: string }; Returns: Json }
      repair_return_part: { Args: { p_part_id: string; p_note?: string }; Returns: Json }
      repair_start_repair: { Args: { p_order_id: string }; Returns: Json }
      repair_waiting_part: { Args: { p_order_id: string; p_note: string }; Returns: Json }
      repair_start_qc: { Args: { p_order_id: string }; Returns: Json }
      repair_record_qc: { Args: { p_order_id: string; p_passed: boolean; p_findings: string; p_conclusion?: string }; Returns: Json }
      repair_mark_returned: { Args: { p_order_id: string }; Returns: Json }
      repair_complete: { Args: { p_order_id: string }; Returns: Json }
      repair_no_fix: { Args: { p_order_id: string; p_reason: string }; Returns: Json }
      repair_warranty_transfer: { Args: { p_order_id: string; p_note: string }; Returns: Json }
      repair_resume_warranty: { Args: { p_order_id: string }; Returns: Json }
      repair_cancel: { Args: { p_order_id: string; p_reason: string }; Returns: Json }
      checklist_template_create: {
        Args: {
          p_template_code: string
          p_name: string
          p_module: string
          p_entity_type: string
          p_description?: string
        }
        Returns: Json
      }
      checklist_template_add_item: {
        Args: {
          p_template_id: string
          p_item_key: string
          p_label: string
          p_sort_order: number
          p_requirement_rule?: string
          p_system_managed?: boolean
          p_description?: string
        }
        Returns: Json
      }
      checklist_template_activate: {
        Args: { p_template_id: string }
        Returns: Json
      }
      checklist_run_start: {
        Args: {
          p_template_id: string
          p_entity_type: string
          p_entity_id: string
          p_note?: string
        }
        Returns: Json
      }
      checklist_run_set_item: {
        Args: {
          p_run_item_id: string
          p_checked: boolean
          p_note?: string
        }
        Returns: Json
      }
      checklist_run_refresh: {
        Args: { p_run_id: string }
        Returns: Json
      }
      checklist_run_complete: {
        Args: { p_run_id: string }
        Returns: Json
      }
      checklist_run_reopen: {
        Args: { p_run_id: string; p_note?: string }
        Returns: Json
      }
      checklist_run_cancel: {
        Args: { p_run_id: string; p_note: string }
        Returns: Json
      }
      warranty_create_sale: {
        Args: { p_sales_order_item_id: string; p_inventory_unit_id?: string; p_customer_device_id?: string; p_start_date?: string; p_warranty_months?: number; p_coverage?: string; p_note?: string }
        Returns: Json
      }
      warranty_create_repair: {
        Args: { p_repair_order_id: string; p_start_date?: string; p_warranty_months?: number; p_coverage?: string; p_note?: string }
        Returns: Json
      }
      warranty_void: { Args: { p_warranty_id: string; p_reason: string }; Returns: Json }
      warranty_claim_create: {
        Args: { p_warranty_id: string; p_issue_description: string; p_intake_condition?: string; p_customer_request?: string; p_assigned_technician_id?: string }
        Returns: Json
      }
      warranty_claim_start_checking: { Args: { p_claim_id: string; p_assigned_technician_id?: string; p_note?: string }; Returns: Json }
      warranty_claim_decide: { Args: { p_claim_id: string; p_approved: boolean; p_note?: string }; Returns: Json }
      warranty_claim_start_service: { Args: { p_claim_id: string; p_service_note?: string }; Returns: Json }
      warranty_claim_update_service: { Args: { p_claim_id: string; p_service_note: string; p_resolution?: string }; Returns: Json }
      warranty_claim_start_qc: { Args: { p_claim_id: string }; Returns: Json }
      warranty_claim_record_qc: { Args: { p_claim_id: string; p_passed: boolean; p_note: string; p_resolution?: string }; Returns: Json }
      warranty_claim_mark_returned: { Args: { p_claim_id: string; p_note?: string }; Returns: Json }
      warranty_claim_close: { Args: { p_claim_id: string; p_note?: string }; Returns: Json }
      warranty_public_lookup_server: { Args: { p_token: string }; Returns: Json }
      warranty_public_lookup: { Args: { p_token: string }; Returns: Json }
      service_create: {
        Args: {
          p_name: string
          p_category?: string
          p_description?: string
          p_interval_count?: number
          p_interval_unit?: string
          p_default_price?: number
          p_warranty_months?: number
        }
        Returns: Json
      }
      service_update: {
        Args: {
          p_service_id: string
          p_name: string
          p_category: string
          p_description: string
          p_interval_count: number
          p_interval_unit: string
          p_default_price: number
          p_warranty_months: number
          p_is_active: boolean
        }
        Returns: Json
      }
      service_schedule_create: {
        Args: {
          p_service_id: string
          p_customer_id: string
          p_customer_device_id?: string
          p_start_date?: string
          p_next_due_date?: string
          p_interval_count?: number
          p_interval_unit?: string
          p_price?: number
          p_end_date?: string
          p_note?: string
        }
        Returns: Json
      }
      service_schedule_update: {
        Args: {
          p_schedule_id: string
          p_next_due_date: string
          p_interval_count: number
          p_interval_unit: string
          p_price: number
          p_end_date?: string
          p_note?: string
        }
        Returns: Json
      }
      service_schedule_set_status: {
        Args: { p_schedule_id: string; p_status: string; p_note?: string }
        Returns: Json
      }
      service_schedule_complete: {
        Args: { p_schedule_id: string; p_note?: string }
        Returns: Json
      }
      software_product_create: {
        Args: {
          p_category: string
          p_vendor: string
          p_name: string
          p_edition?: string
          p_billing_model?: string
          p_default_term_months?: number
          p_description?: string
        }
        Returns: Json
      }
      software_product_update: {
        Args: {
          p_product_id: string
          p_category: string
          p_vendor: string
          p_name: string
          p_edition: string
          p_billing_model: string
          p_default_term_months: number
          p_description: string
          p_is_active: boolean
        }
        Returns: Json
      }
      software_license_create: {
        Args: {
          p_software_product_id: string
          p_customer_id: string
          p_customer_device_id?: string
          p_start_date?: string
          p_end_date?: string
          p_seats?: number
          p_account_identifier?: string
          p_secret_ref?: string
          p_auto_renew?: boolean
          p_renewal_cost?: number
          p_note?: string
        }
        Returns: Json
      }
      software_license_update: {
        Args: {
          p_license_id: string
          p_seats: number
          p_account_identifier: string
          p_secret_ref: string
          p_auto_renew: boolean
          p_renewal_cost: number
          p_note?: string
        }
        Returns: Json
      }
      software_license_renew: {
        Args: {
          p_license_id: string
          p_term_months: number
          p_renewal_cost?: number
          p_note?: string
        }
        Returns: Json
      }
      software_license_set_status: {
        Args: { p_license_id: string; p_status: string; p_reason?: string }
        Returns: Json
      }
      warranty_create_service: {
        Args: {
          p_schedule_id: string
          p_warranty_months?: number
          p_coverage?: string
          p_note?: string
        }
        Returns: Json
      }
      reminder_rule_create: {
        Args: {
          p_rule_code: string
          p_name: string
          p_event_type: string
          p_offset_minutes?: number
          p_priority?: string
          p_description?: string
          p_is_active?: boolean
        }
        Returns: Json
      }
      reminder_rule_update: {
        Args: {
          p_rule_id: string
          p_name: string
          p_offset_minutes: number
          p_priority: string
          p_is_active: boolean
          p_description?: string
        }
        Returns: Json
      }
      reminder_generate: {
        Args: { p_now?: string }
        Returns: Json
      }
      reminder_acknowledge: {
        Args: { p_reminder_id: string; p_note?: string }
        Returns: Json
      }
      reminder_snooze: {
        Args: { p_reminder_id: string; p_snoozed_until: string; p_note?: string }
        Returns: Json
      }
      reminder_resolve: {
        Args: { p_reminder_id: string; p_reason: string; p_note?: string }
        Returns: Json
      }
      notification_rule_configure: {
        Args: {
          p_rule_id: string
          p_staff_channels: string[]
          p_customer_channels: string[]
        }
        Returns: Json
      }
      notification_channel_configure: {
        Args: {
          p_channel: string
          p_enabled: boolean
          p_config: Json
          p_secret_ref?: string
        }
        Returns: Json
      }
      notification_prepare: {
        Args: { p_now?: string }
        Returns: Json
      }
      notification_claim_batch: {
        Args: { p_channel: string; p_limit?: number; p_now?: string }
        Returns: NotificationRow[]
      }
      notification_mark_sent: {
        Args: { p_notification_id: string; p_external_message_id?: string; p_response_meta?: Json }
        Returns: Json
      }
      notification_mark_failed: {
        Args: {
          p_notification_id: string
          p_error_code: string
          p_error_message: string
          p_response_meta?: Json
          p_retry_after_seconds?: number
        }
        Returns: Json
      }
      notification_requeue_stale: {
        Args: { p_older_than_minutes?: number }
        Returns: Json
      }
      notification_mark_read: {
        Args: { p_notification_id: string }
        Returns: Json
      }
      notification_mark_all_read: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      notification_retry: {
        Args: { p_notification_id: string }
        Returns: Json
      }
      notification_cancel: {
        Args: { p_notification_id: string; p_reason: string }
        Returns: Json
      }
      audit_search: {
        Args: {
          p_start_at?: string | null
          p_end_at?: string | null
          p_table_name?: string | null
          p_action?: string | null
          p_actor_user_id?: string | null
          p_record_id?: string | null
          p_before_id?: number | null
          p_limit?: number
        }
        Returns: Json
      }
      security_audit_snapshot: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      dashboard_snapshot: {
        Args: { p_days?: number; p_now?: string }
        Returns: Json
      }
      report_snapshot: {
        Args: {
          p_start_date: string
          p_end_date: string
          p_bucket?: string
          p_now?: string
        }
        Returns: Json
      }
      inventory_adjust: {
        Args: {
          p_product_id: string
          p_quantity_delta: number
          p_note: string
          p_unit_cost?: number
          p_serial_numbers?: string[]
          p_inventory_unit_ids?: string[]
          p_location?: string
        }
        Returns: Json
      }
      qr_issue: {
        Args: {
          p_resource_type: string
          p_reference?: string | null
          p_intent?: string
          p_expires_at?: string | null
        }
        Returns: Json
      }
      qr_resolve: {
        Args: { p_token: string }
        Returns: Json
      }
      qr_revoke: {
        Args: { p_token: string }
        Returns: Json
      }
    }
    Enums: Record<string, never>
    CompositeTypes: Record<string, never>
  }
}
