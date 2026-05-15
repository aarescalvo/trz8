---
Task ID: 1
Agent: Main Agent
Task: Corregir error al crear productor - modelo ProductorConsignatario faltante

Work Log:
- Investigado el error: el modelo ProductorConsignatario y el enum TipoProductor no existían en prisma/schema.prisma activo
- Verificado que la API route /api/productores usa db.productorConsignatario.create()
- Encontrado el modelo en schema-postgresql-original.prisma pero no migrado al schema activo
- Agregado el modelo ProductorConsignatario con todos sus campos al schema.prisma activo
- Agregado el enum TipoProductor (PRODUCTOR, CONSIGNATARIO, AMBOS)
- Relaciones de Tropa/DeclaracionJurada no incluidas para evitar conflicto con Cliente
- Generado Prisma client exitosamente (prisma@6 generate)
- Creada migración SQL manual en prisma/migrations/20260515_add_productor_consignatario/migration.sql
- Commit creado localmente: "fix: agregar modelo ProductorConsignatario faltante al schema.prisma"
- Push falló por falta de credenciales GitHub en este entorno

Stage Summary:
- El modelo ProductorConsignatario fue agregado al schema.prisma y el Prisma client regenerado
- Se necesita: (1) push al repo, (2) ejecutar la migración SQL en la base de datos PostgreSQL del usuario, (3) reiniciar la app
