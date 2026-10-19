# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Product Purpose

kwall reúne dinero, notas y hábitos con una mascota que acompaña al usuario. El inicio debe hacer que esa mascota se sienta propia.

## Users

Inferido del proyecto: personas que llevan sus finanzas y rutinas personales desde su teléfono. No se ha definido otro público.

## Capabilities and Constraints

- Evidencia del código: Flutter, SQLite, cuentas con distintas monedas, gastos, ingresos, transferencias, metas de ahorro, notas y hábitos. Widget de Android.
- Mantener los datos y las rutas existentes de recuperación y respaldo.
- No generar APK durante este trabajo, según la preferencia registrada del proyecto. Verificación mediante análisis, pruebas Flutter y compilación Kotlin sin empaquetar.

## Brand Commitments

- Mascota protagonista; bienvenida de adopción cálida y tranquila, confirmada por el usuario.
- Textos simples y cortos. Preferir imágenes, formas e iconos; no emojis ni términos técnicos en el flujo.
- Conservar los sprites y las variantes de mascotas existentes.

## Evidence on Hand

- `assets/pets/`: sprites adultos y bebés de gatos, ratas, mapaches, zarigüeyas, rocas y plantas.
- `lib/core/theme/kwall_theme.dart`: tema existente claro/oscuro y paletas.
- `lib/features/welcome/`: entrada y persistencia de preferencias.

## Product Principles

- Crear vínculo mediante una elección y una interacción con la mascota.
- Pedir sólo lo necesario para empezar; permitir cambios después.
- Explicar con imágenes e interacciones antes que con párrafos.
- Conservar trazabilidad de movimientos y saldos.
