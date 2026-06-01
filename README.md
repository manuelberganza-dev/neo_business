# Neo Business API

API REST para un POS + inventario multi-sucursal pensado para negocios en El Salvador. La idea es que Rails haga el trabajo serio del backend y que Svelte y Flutter solo consuman endpoints limpios: web para administracion y dashboards, movil para caja rapida, escaneo e inventario.

Stack actual:

- Ruby on Rails 8.1 API-only
- MySQL
- Devise JWT para autenticacion
- Pundit + permisos por rol
- acts_as_tenant con `Store` como tenant principal
- Active Storage para imagenes de productos
- Sidekiq/Redis configurado para jobs
- Solid Cache/Queue/Cable disponible por Rails

## Setup Rapido

```bash
bundle install
bundle exec rails db:prepare
bundle exec rails db:seed
bundle exec rails server
```

Credenciales demo locales:

```text
admin@example.com
password123
```

MySQL local usado en desarrollo:

```yml
username: root
password: root1234
```

## Como Esta Pensada La App

La app es multi-tenant. Eso significa que casi todo vive dentro de una tienda/negocio (`stores`). Cuando un usuario inicia sesion, el backend toma su `store_id` y filtra los datos automaticamente con `acts_as_tenant`.

El flujo general es:

1. El admin crea la tienda, sucursales, bodegas, usuarios y roles.
2. Se cargan catalogos: categorias, unidades, marcas, metodos de pago.
3. Se crean productos con SKU, codigo de barras, precios, costo e impuesto.
4. Inventario se mueve por compras, ajustes, transferencias o ventas.
5. El cajero abre caja.
6. Se crea una venta POS con items y pagos.
7. La venta descuenta inventario y genera kardex.
8. Si se anula, el inventario se repone con movimientos de reversa.
9. El cajero cierra caja.
10. Reportes consultan ventas, margen, stock bajo y kardex.

## Tablas Principales

| Tabla | Para que sirve |
| --- | --- |
| `stores` | Tenant principal: negocio o tienda cliente. Guarda datos fiscales base como NIT/NRC. |
| `branches` | Sucursales de una tienda. |
| `users` | Usuarios del negocio. Cada usuario pertenece a un `store` y opcionalmente a una sucursal. |
| `roles` | Roles como `superadmin`, `admin`, `manager`, `cajero`, `bodeguero`. |
| `permissions` | Permisos tipo `products.read`, `sales.write`, `reports.read`. |
| `user_roles` | Relacion usuarios-roles por tienda. |
| `role_permissions` | Relacion roles-permisos. |
| `categories` | Categorias de productos, con soporte para categoria padre. |
| `units` | Unidades de medida. |
| `brands` | Marcas. |
| `payment_methods` | Metodos de pago configurables por tienda. |
| `products` | Catalogo: SKU, barcode, costo, precio, impuesto, imagen y estado. |
| `warehouses` | Bodegas por sucursal. |
| `inventory_items` | Existencia actual por producto y bodega. |
| `stock_movements` | Kardex: compras, ventas, ajustes, transferencias, anulaciones. |
| `customers` | Clientes con datos fiscales/documentos. |
| `suppliers` | Proveedores con NIT/NRC/contacto. |
| `cash_registers` | Cajas POS por sucursal. |
| `cash_sessions` | Apertura y cierre de caja. |
| `sales` | Encabezado de venta. |
| `sale_items` | Detalle de productos vendidos. |
| `payments` | Pagos de la venta, soporta pago mixto. |
| `invoices` | Documento fiscal/DTE-ready ligado a venta. |
| `purchases` | Compra a proveedor. |
| `purchase_items` | Detalle de compra. |
| `notifications` | Historial persistente de avisos del sistema y eventos de jobs/canales. |
| `audit_logs` | Auditoria de acciones sensibles. |
| `active_storage_*` | Archivos adjuntos, hoy usado para imagen de producto. |

## Relaciones Clave

- `Store has_many branches, users, products, warehouses, sales, purchases`.
- `Branch belongs_to store` y tiene `warehouses`, `cash_registers`, `sales`.
- `User belongs_to store` y puede pertenecer a una `branch`.
- `User has_many roles through user_roles`.
- `Role has_many permissions through role_permissions`.
- `Product belongs_to store, unit, category, brand`.
- `Product has_many inventory_items` y `stock_movements`.
- `Warehouse belongs_to branch` y tiene inventario.
- `InventoryItem` es unico por `store_id + product_id + warehouse_id`.
- `Sale has_many sale_items, payments` y puede tener una `invoice`.
- `SaleItem belongs_to product`.
- `Purchase has_many purchase_items`.
- `StockMovement` puede referenciar ventas, compras u otros movimientos con `reference_type/reference_id`.

## Seguridad

Todas las rutas de negocio usan JWT:

```http
Authorization: Bearer TOKEN
```

El backend valida:

- usuario activo
- JWT valido
- `jti` vigente
- tenant actual desde `current_user.store`
- permiso requerido, por ejemplo `products.write`

Los roles admin/superadmin pasan todas las policies internas actuales.

## Tiempo Real Con Action Cable

WebSocket:

```text
/cable?token=JWT
```

Los canales tambien respetan tenant y permisos. Si el token no es valido, la conexion se rechaza.

| Canal | Stream | Eventos principales |
| --- | --- | --- |
| `InventoryChannel` | Inventario de la tienda | `stock_updated`, `low_stock`, `adjustment_created` |
| `SalesChannel` | Ventas de la tienda | `sale_created`, `sale_voided`, `daily_total_updated` |
| `NotificationChannel` | Notificaciones tienda/usuario | `system_alert`, `job_finished`, `ocr_ready`, `purchase_received` |
| `PosChannel` | Sincronizacion POS | `cash_session_opened`, `cash_session_closed`, `product_price_updated`, `terminal_sync` |

Ejemplo de mensaje recibido:

```json
{
  "event": "stock_updated",
  "payload": {
    "product_id": 10,
    "product_name": "Cafe molido 400g",
    "warehouse_id": 1,
    "warehouse_name": "Bodega matriz",
    "movement_type": "sale",
    "qty": "-2.0",
    "quantity": "8.0",
    "min_stock": "2.0",
    "low_stock": false
  },
  "sent_at": "2026-05-28T15:47:01-06:00"
}
```

## Endpoints

Base URL:

```text
/api/v1
```

### Auth

| Metodo | Endpoint | Uso |
| --- | --- | --- |
| `POST` | `/auth/login` | Inicia sesion y devuelve JWT en header `Authorization`. |
| `DELETE` | `/auth/logout` | Cierra sesion del lado cliente/API. |
| `GET` | `/me` | Usuario actual, tienda, roles y permisos. |

### Administracion

Estos tienen CRUD completo: `GET index`, `POST create`, `GET show`, `PATCH update`, `DELETE deactivate/destroy`.

| Recurso | Endpoint |
| --- | --- |
| Stores | `/stores` |
| Branches | `/branches` |
| Users | `/users` |
| Roles | `/roles` |
| Permissions | `/permissions` solo `GET` |
| Categories | `/categories` |
| Units | `/units` |
| Brands | `/brands` |
| Payment Methods | `/payment_methods` |
| Products | `/products` |
| Warehouses | `/warehouses` |
| Cash Registers | `/cash_registers` |
| Customers | `/customers` |
| Suppliers | `/suppliers` |

Filtros utiles:

```text
GET /products?name=cafe&sku=ABC&barcode=750123&category_id=1&active=true
GET /customers?name=juan&nit=0614&nrc=123&phone=7777
GET /suppliers?name=distribuidora&nit=0614&nrc=123
GET /warehouses?branch_id=1
GET /warehouses?include_inactive=true
GET /warehouses?active=false
GET /cash_registers?branch_id=1&status=available
GET /users?branch_id=1&active=true&email=admin
```

Nota rapida: `/warehouses` ahora devuelve solo bodegas activas por defecto. Para ver todo se usa `include_inactive=true`; para buscar solo inactivas se usa `active=false`.

### Inventario

| Metodo | Endpoint | Uso |
| --- | --- | --- |
| `GET` | `/inventory` | Existencias por producto/bodega. |
| `PATCH` | `/inventory/:id` | Actualiza `min_stock`. |
| `GET` | `/inventory/products/:product_id/kardex` | Kardex por producto. |
| `GET` | `/inventory/warehouses/:warehouse_id/history` | Historial de bodega. |
| `GET` | `/stock_movements` | Kardex filtrado. |
| `POST` | `/stock_movements` | Ajuste manual/entrada/salida. |
| `POST` | `/stock_movements/transfer` | Transferencia entre bodegas. |

Filtros comunes:

```text
GET /stock_movements?from=2026-05-01&to=2026-05-30&product_id=10&warehouse_id=1
GET /reports/kardex?from=2026-05-01&to=2026-05-30&branch_id=1&warehouse_id=1
GET /reports/low_stock?branch_id=1&warehouse_id=1
```

### POS y Compras

| Metodo | Endpoint | Uso |
| --- | --- | --- |
| `GET` | `/cash_registers` | Lista cajas POS por sucursal/estado. |
| `POST` | `/cash_registers` | Crea una caja POS. |
| `PATCH` | `/cash_registers/:id` | Edita una caja POS. |
| `DELETE` | `/cash_registers/:id` | Marca la caja como inactiva. |
| `GET` | `/cash_sessions/current` | Devuelve la caja abierta actual, opcional por caja o usuario. |
| `GET` | `/cash_sessions` | Historico de aperturas/cierres para arqueos y auditoria. |
| `GET` | `/cash_sessions/:id` | Detalle de una sesion de caja con resumen por metodo. |
| `POST` | `/cash_sessions/open` | Abre caja. |
| `POST` | `/cash_sessions/:id/close` | Cierra caja y devuelve resumen por metodo de pago. |
| `POST` | `/sales` | Crea venta POS, pagos y descuenta inventario. |
| `GET` | `/sales` | Historial de ventas. |
| `GET` | `/sales/:id` | Detalle de venta. |
| `POST` | `/sales/:id/void` | Anula venta y repone inventario. |
| `GET` | `/purchases` | Historial de compras. |
| `GET` | `/purchases/:id` | Detalle de compra. |
| `POST` | `/purchases` | Compra proveedor y entrada a inventario. |
| `POST` | `/purchases/:id/void` | Anula compra recibida y revierte inventario. |

Filtros utiles:

```text
GET /sales?status=paid&from=2026-05-01&to=2026-05-30&branch_id=1&cash_session_id=5
GET /sales?sale_number=V20260530101000123456&customer_id=3
GET /cash_sessions?status=closed&from=2026-05-01&to=2026-05-30&branch_id=1&user_id=4
GET /purchases?status=received&supplier_id=1&warehouse_id=1&from=2026-05-01&to=2026-05-30
```

### Movil y Reportes

| Metodo | Endpoint | Uso |
| --- | --- | --- |
| `POST` | `/mobile/scan_product` | Busca producto por barcode. |
| `GET` | `/reports/daily_sales` | Ventas del dia. |
| `GET` | `/reports/sales` | Ventas por rango. |
| `GET` | `/reports/sales_by_cashier` | Ventas agrupadas por cajero. |
| `GET` | `/reports/sales_by_hour` | Ventas agrupadas por hora para dashboard. |
| `GET` | `/reports/payment_methods` | Totales por metodo de pago. |
| `GET` | `/reports/top_products` | Productos mas vendidos. |
| `GET` | `/reports/gross_margin` | Margen bruto. |
| `GET` | `/reports/low_stock` | Productos bajo minimo. |
| `GET` | `/reports/kardex` | Kardex reportable. |

Los reportes aceptan filtros consistentes cuando aplica:

```text
from=2026-05-01
to=2026-05-30
branch_id=1
warehouse_id=1
```

### Notificaciones

| Metodo | Endpoint | Uso |
| --- | --- | --- |
| `GET` | `/notifications` | Historial de notificaciones. |
| `GET` | `/notifications/:id` | Detalle de una notificacion. |
| `PATCH` | `/notifications/:id/read` | Marca una notificacion como leida. |
| `PATCH` | `/notifications/read_all` | Marca varias como leidas segun filtros. |

Filtros utiles:

```text
GET /notifications?unread=true
GET /notifications?event=purchase_received&from=2026-05-01&to=2026-05-30
PATCH /notifications/read_all?unread=true
```

## Ejemplos JSON Para Svelte

Svelte normalmente va a manejar administracion, catalogos y reportes.

### Login

```json
{
  "user": {
    "email": "admin@example.com",
    "password": "password123"
  }
}
```

El JWT llega en el header:

```text
Authorization: Bearer eyJhbGciOi...
```

### Crear Producto

`POST /api/v1/products`

```json
{
  "product": {
    "category_id": 1,
    "unit_id": 1,
    "brand_id": 1,
    "sku": "CAF-001",
    "barcode": "750100000001",
    "name": "Cafe molido 400g",
    "description": "Cafe tostado y molido",
    "cost": "2.50",
    "price": "4.99",
    "tax_rate": "0.13",
    "track_inventory": true,
    "active": true
  }
}
```

Para imagen de producto, Svelte debe enviar `multipart/form-data` con el campo:

```text
product[image]
```

La respuesta de productos y escaneo devuelve `image_url` absoluta cuando el producto tiene imagen, lista para usarla en `<img src="...">` o en un `Image.network(...)` desde Flutter:

```json
{
  "product": {
    "id": 10,
    "image_attached": true,
    "image_url": "http://localhost:3000/rails/active_storage/blobs/redirect/..."
  }
}
```

### Crear Usuario Con Roles

`POST /api/v1/users`

```json
{
  "user": {
    "branch_id": 1,
    "email": "cajero@example.com",
    "full_name": "Carlos Cajero",
    "password": "password123",
    "password_confirmation": "password123",
    "active": true,
    "role_ids": [3]
  }
}
```

### Crear Caja POS

`POST /api/v1/cash_registers`

```json
{
  "cash_register": {
    "branch_id": 1,
    "code": "CAJA-01",
    "name": "Caja principal",
    "status": "available"
  }
}
```

Respuesta resumida:

```json
{
  "cash_register": {
    "id": 1,
    "store_id": 1,
    "branch_id": 1,
    "branch_name": "Sucursal Centro",
    "code": "CAJA-01",
    "name": "Caja principal",
    "status": "available",
    "current_cash_session_id": null
  }
}
```

### Crear Bodega Activa

`POST /api/v1/warehouses`

```json
{
  "warehouse": {
    "branch_id": 1,
    "code": "BOD-01",
    "name": "Bodega principal",
    "active": true
  }
}
```

### Crear Cliente Fiscal

`POST /api/v1/customers`

```json
{
  "customer": {
    "name": "Cliente Final",
    "document_type": "dui",
    "document_number": "01234567-8",
    "nit": "0614-010190-101-0",
    "nrc": "123456-7",
    "email": "cliente@example.com",
    "phone": "7777-7777",
    "address": "San Salvador",
    "active": true
  }
}
```

### Crear Proveedor

`POST /api/v1/suppliers`

```json
{
  "supplier": {
    "name": "Distribuidora Central",
    "nit": "0614-020290-102-0",
    "nrc": "654321-0",
    "email": "ventas@proveedor.com",
    "phone": "2222-1111",
    "address": "Santa Tecla",
    "active": true
  }
}
```

### Reporte De Ventas

`GET /api/v1/reports/sales?from=2026-05-01&to=2026-05-28&branch_id=1`

Respuesta resumida:

```json
{
  "from": "2026-05-01T00:00:00.000-06:00",
  "to": "2026-05-28T00:00:00.000-06:00",
  "sales_count": 12,
  "subtotal": "1200.00",
  "tax": "156.00",
  "discount": "0.00",
  "total": "1356.00",
  "branch_id": "1",
  "warehouse_id": null
}
```

### Reporte Por Hora

`GET /api/v1/reports/sales_by_hour?from=2026-05-30&to=2026-05-30&branch_id=1`

```json
{
  "from": "2026-05-30T00:00:00.000-06:00",
  "to": "2026-05-30T23:59:59.999-06:00",
  "branch_id": "1",
  "warehouse_id": null,
  "hours": [
    {
      "hour": "2026-05-30 09:00:00",
      "sales_count": 8,
      "total": "245.75"
    }
  ]
}
```

### Reporte Por Metodo De Pago

`GET /api/v1/reports/payment_methods?from=2026-05-30&to=2026-05-30&branch_id=1`

```json
{
  "payment_methods": [
    {
      "method": "EFECTIVO",
      "amount": "80.25",
      "payments_count": 5
    },
    {
      "method": "TARJETA",
      "amount": "45.0",
      "payments_count": 2
    }
  ]
}
```

## Ejemplos JSON Para Flutter

Flutter va mejor para flujos rapidos: escanear, abrir caja, vender, inventario fisico y compras rapidas.

### Buscar Producto Por Barcode

`POST /api/v1/mobile/scan_product`

```json
{
  "scan": {
    "barcode": "750100000001",
    "warehouse_id": 1
  }
}
```

Tambien puede mandar `branch_id` si el usuario movil quiere ver stock de una sucursal completa. Si no manda bodega ni sucursal, la API usa la sucursal asignada al usuario cuando exista.

Respuesta resumida:

```json
{
  "product": {
    "id": 10,
    "sku": "CAF-001",
    "barcode": "750100000001",
    "name": "Cafe molido 400g",
    "unit_code": "UND",
    "category_name": "Abarrotes",
    "brand_name": "Marca Local",
    "cost": "2.5",
    "price": "4.99",
    "tax_rate": "0.13",
    "track_inventory": true,
    "active": true,
    "image_attached": true,
    "image_url": "http://localhost:3000/rails/active_storage/blobs/redirect/..."
  },
  "stock": {
    "total_quantity": "18.0",
    "warehouse": {
      "warehouse_id": 1,
      "warehouse_code": "BOD-01",
      "warehouse_name": "Bodega principal",
      "branch_id": 1,
      "branch_name": "Sucursal Centro",
      "quantity": "18.0",
      "min_stock": "5.0",
      "low_stock": false
    },
    "warehouses": [
      {
        "warehouse_id": 1,
        "warehouse_code": "BOD-01",
        "warehouse_name": "Bodega principal",
        "branch_id": 1,
        "branch_name": "Sucursal Centro",
        "quantity": "18.0",
        "min_stock": "5.0",
        "low_stock": false
      }
    ]
  }
}
```

### Escanear Factura Con OCR

Configura la integracion con variables de entorno. No subas el API key al repositorio; `.env*` ya esta ignorado por Git.

```bash
GEMINI_API_KEY=tu_api_key
GEMINI_MODEL=gemini-flash-latest
GEMINI_MODELS=gemini-flash-latest
GEMINI_TIMEOUT=18
GEMINI_MAX_RETRIES=0
GEMINI_RETRY_DELAY=0.5
OCR_PHOTO_STORAGE_PATH=C:/Users/Manuel Berganza/Desktop/fotos_rails
```

`GEMINI_MODELS` acepta varios modelos separados por coma para fallback cuando Google responda con saturacion o limite temporal. Por ejemplo: `GEMINI_MODELS=gemini-flash-latest,gemini-2.0-flash`.

`POST /api/v1/mobile/ocr/scan`

Enviar como `multipart/form-data` desde Flutter, incluyendo el mismo JWT que se obtiene en login:

```http
Authorization: Bearer TOKEN
```

```json
{
  "scan": {
    "photo": "<archivo>"
  }
}
```

La API guarda una copia local de la foto en `OCR_PHOTO_STORAGE_PATH`, envia esa imagen a Gemini Flash y devuelve los campos listos para pintar en el formulario:

```json
{
  "ocr": {
    "document_type": "CCF",
    "document_number": "DTE-000123",
    "control_number": "DTE-01-00000001",
    "generation_code": "ABC-123",
    "issued_at": "2026-06-01T10:00:00-06:00",
    "supplier": {
      "name": "Proveedor S.A. de C.V.",
      "nit": "0614-000000-000-0",
      "nrc": "123456-7",
      "activity": "Venta",
      "address": "San Salvador"
    },
    "customer": {
      "name": "Cliente Demo",
      "nit": null,
      "nrc": null
    },
    "currency": "USD",
    "subtotal": 10.0,
    "tax": 1.3,
    "discount": 0.0,
    "total": 11.3,
    "items": [
      {
        "description": "Producto",
        "quantity": 1.0,
        "unit_price": 10.0,
        "tax_rate": 0.13,
        "total": 11.3
      }
    ],
    "confidence": 0.92,
    "warnings": []
  },
  "photo": {
    "reference": "20260601100000000000-abcd1234.jpg",
    "original_filename": "factura.jpg"
  }
}
```

Cuando el usuario verifique los campos y toque guardar, Flutter debe enviar la version corregida:

`POST /api/v1/mobile/ocr/documents`

```json
{
  "ocr_document": {
    "photo_reference": "20260601100000000000-abcd1234.jpg",
    "document_type": "CCF",
    "document_number": "DTE-000123",
    "control_number": "DTE-01-00000001",
    "generation_code": "ABC-123",
    "issued_at": "2026-06-01T10:00:00-06:00",
    "supplier": {
      "name": "Proveedor S.A. de C.V.",
      "nit": "0614-000000-000-0",
      "nrc": "123456-7",
      "activity": "Venta",
      "address": "San Salvador"
    },
    "customer": {
      "name": "Cliente Demo",
      "nit": null,
      "nrc": null
    },
    "currency": "USD",
    "subtotal": 10.0,
    "tax": 1.3,
    "discount": 0.0,
    "total": 11.3,
    "items": [
      {
        "description": "Producto",
        "quantity": 1.0,
        "unit_price": 10.0,
        "tax_rate": 0.13,
        "total": 11.3
      }
    ],
    "confidence": 0.92,
    "warnings": []
  }
}
```

### Abrir Caja

`POST /api/v1/cash_sessions/open`

```json
{
  "cash_session": {
    "cash_register_id": 1,
    "opening_amount": "50.00"
  }
}
```

### Consultar Caja Abierta Actual

`GET /api/v1/cash_sessions/current?cash_register_id=1`

Respuesta resumida:

```json
{
  "cash_session": {
    "id": 1,
    "cash_register_id": 1,
    "cash_register_name": "Caja principal",
    "branch_id": 1,
    "branch_name": "Sucursal Centro",
    "user_id": 5,
    "opening_amount": "50.0",
    "expected_amount": "72.6",
    "difference_amount": "0.0",
    "payment_summary": [
      {
        "method": "EFECTIVO",
        "amount": "22.6",
        "payments_count": 1
      }
    ],
    "status": "open",
    "opened_at": "2026-05-30T09:00:00.000-06:00",
    "closed_at": null
  }
}
```

Para pedir solo la caja abierta del usuario autenticado:

```text
GET /api/v1/cash_sessions/current?mine=true
```

### Historico De Caja

`GET /api/v1/cash_sessions?status=closed&branch_id=1&from=2026-05-01&to=2026-05-30`

```json
{
  "cash_sessions": [
    {
      "id": 1,
      "cash_register_id": 1,
      "cash_register_name": "Caja principal",
      "branch_id": 1,
      "branch_name": "Sucursal Centro",
      "user_id": 5,
      "user_name": "Carlos Cajero",
      "opening_amount": "50.0",
      "closing_amount": "175.25",
      "expected_amount": "175.25",
      "difference_amount": "0.0",
      "status": "closed"
    }
  ]
}
```

### Venta POS Con Pago Mixto

`POST /api/v1/sales`

```json
{
  "sale": {
    "branch_id": 1,
    "cash_session_id": 1,
    "warehouse_id": 1,
    "customer_id": 2,
    "idempotency_key": "device-01-sale-000001",
    "items": [
      {
        "product_id": 10,
        "quantity": "2",
        "unit_price": "4.99",
        "discount": "0.00"
      },
      {
        "product_id": 11,
        "quantity": "1",
        "unit_price": "1.50",
        "discount": "0.00"
      }
    ],
    "payments": [
      {
        "method": "EFECTIVO",
        "amount": "5.00"
      },
      {
        "method": "TARJETA",
        "amount": "7.99",
        "reference": "POS-APPROVAL-123"
      }
    ],
    "invoice": {
      "doc_type": "ticket",
      "customer_name": "Cliente Final",
      "customer_document_type": "dui",
      "customer_document_number": "01234567-8"
    }
  }
}
```

Nota: `idempotency_key` ayuda a que Flutter pueda reintentar una venta si pierde conexion sin duplicarla.

### Anular Venta

`POST /api/v1/sales/15/void`

```json
{
  "sale": {
    "reason": "Cliente solicito anulacion antes de retirar producto"
  }
}
```

### Ajuste Manual De Inventario

`POST /api/v1/stock_movements`

```json
{
  "stock_movement": {
    "product_id": 10,
    "warehouse_id": 1,
    "movement_type": "adjustment",
    "qty": "5",
    "unit_cost": "2.50",
    "notes": "Conteo fisico encontro 5 unidades adicionales",
    "allow_negative": false
  }
}
```

### Transferencia Entre Bodegas

`POST /api/v1/stock_movements/transfer`

```json
{
  "transfer": {
    "product_id": 10,
    "from_warehouse_id": 1,
    "to_warehouse_id": 2,
    "qty": "3",
    "notes": "Reabastecimiento de sucursal"
  }
}
```

### Registrar Compra A Proveedor

`POST /api/v1/purchases`

```json
{
  "purchase": {
    "supplier_id": 1,
    "warehouse_id": 1,
    "document_type": "CCF",
    "invoice_number": "DTE-000123",
    "discount": "0.00",
    "items": [
      {
        "product_id": 10,
        "quantity": "12",
        "cost": "2.30",
        "tax_rate": "0.13",
        "update_product_cost": true
      }
    ]
  }
}
```

### Consultar Y Anular Compra

`GET /api/v1/purchases?status=received&warehouse_id=1`

`POST /api/v1/purchases/10/void`

```json
{
  "purchase": {
    "reason": "Factura duplicada"
  }
}
```

Al anular, el backend crea movimientos de inventario negativos contra la misma bodega y deja la compra en `voided`.

### Leer Notificaciones

`GET /api/v1/notifications?unread=true`

```json
{
  "notifications": [
    {
      "id": 20,
      "event": "purchase_received",
      "title": "Purchase received",
      "metadata": {
        "purchase_id": 10,
        "warehouse_id": 1,
        "total": "31.64"
      },
      "read": false,
      "created_at": "2026-05-30T10:00:00.000-06:00"
    }
  ]
}
```

`PATCH /api/v1/notifications/20/read`

### Cerrar Caja

`POST /api/v1/cash_sessions/1/close`

```json
{
  "cash_session": {
    "closing_amount": "175.25"
  }
}
```

Respuesta resumida:

```json
{
  "id": 1,
  "cash_register_id": 1,
  "cash_register_name": "Caja principal",
  "opening_amount": "50.0",
  "closing_amount": "175.25",
  "expected_amount": "175.25",
  "difference_amount": "0.0",
  "payment_summary": [
    {
      "method": "EFECTIVO",
      "amount": "80.25",
      "payments_count": 5
    },
    {
      "method": "TARJETA",
      "amount": "45.0",
      "payments_count": 2
    }
  ],
  "status": "closed"
}
```

## Flujo Recomendado Web + Movil

Svelte:

1. Login.
2. Crear tienda/sucursal/bodega/caja.
3. Crear usuarios y roles.
4. Crear catalogos.
5. Crear productos y cargar imagenes.
6. Revisar reportes, stock bajo y kardex.

Flutter:

1. Login del cajero o bodeguero.
2. Abrir caja o seleccionar bodega.
3. Escanear producto.
4. Crear venta o movimiento de inventario.
5. Sincronizar resultado con la API.
6. Cerrar caja al final del turno.

## Comandos De Calidad

```bash
bundle exec rails test
bundle exec rails zeitwerk:check
bundle exec rubocop
```

Estado actual verificado:

```text
8 tests, 104 assertions, 0 failures, 0 errors
101 files inspected, no offenses detected
Zeitwerk: All is good
```

En Windows puede aparecer una advertencia de VIPS por modulos opcionales de imagen (`vips-heif`, `vips-jxl`, etc.). No rompe la API ni la base de datos.
