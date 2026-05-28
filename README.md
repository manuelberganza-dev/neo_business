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
| Customers | `/customers` |
| Suppliers | `/suppliers` |

Filtros utiles:

```text
GET /products?name=cafe&sku=ABC&barcode=750123&category_id=1&active=true
GET /customers?name=juan&nit=0614&nrc=123&phone=7777
GET /suppliers?name=distribuidora&nit=0614&nrc=123
GET /warehouses?branch_id=1&active=true
GET /users?branch_id=1&active=true&email=admin
```

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

### POS y Compras

| Metodo | Endpoint | Uso |
| --- | --- | --- |
| `POST` | `/cash_sessions/open` | Abre caja. |
| `POST` | `/cash_sessions/:id/close` | Cierra caja. |
| `POST` | `/sales` | Crea venta POS, pagos y descuenta inventario. |
| `GET` | `/sales` | Historial de ventas. |
| `GET` | `/sales/:id` | Detalle de venta. |
| `POST` | `/sales/:id/void` | Anula venta y repone inventario. |
| `POST` | `/purchases` | Compra proveedor y entrada a inventario. |

### Movil y Reportes

| Metodo | Endpoint | Uso |
| --- | --- | --- |
| `POST` | `/mobile/scan_product` | Busca producto por barcode. |
| `GET` | `/reports/daily_sales` | Ventas del dia. |
| `GET` | `/reports/sales` | Ventas por rango. |
| `GET` | `/reports/sales_by_cashier` | Ventas agrupadas por cajero. |
| `GET` | `/reports/top_products` | Productos mas vendidos. |
| `GET` | `/reports/gross_margin` | Margen bruto. |
| `GET` | `/reports/low_stock` | Productos bajo minimo. |
| `GET` | `/reports/kardex` | Kardex reportable. |

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

`GET /api/v1/reports/sales?from=2026-05-01&to=2026-05-28`

Respuesta resumida:

```json
{
  "from": "2026-05-01T00:00:00.000-06:00",
  "to": "2026-05-28T00:00:00.000-06:00",
  "sales_count": 12,
  "subtotal": "1200.00",
  "tax": "156.00",
  "discount": "0.00",
  "total": "1356.00"
}
```

## Ejemplos JSON Para Flutter

Flutter va mejor para flujos rapidos: escanear, abrir caja, vender, inventario fisico y compras rapidas.

### Buscar Producto Por Barcode

`POST /api/v1/mobile/scan_product`

```json
{
  "scan": {
    "barcode": "750100000001"
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

### Cerrar Caja

`POST /api/v1/cash_sessions/1/close`

```json
{
  "cash_session": {
    "closing_amount": "175.25"
  }
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
5 tests, 39 assertions, 0 failures, 0 errors
89 files inspected, no offenses detected
Zeitwerk: All is good
```

En Windows puede aparecer una advertencia de VIPS por modulos opcionales de imagen (`vips-heif`, `vips-jxl`, etc.). No rompe la API ni la base de datos.
