# Survivors Arena

Starter de un juego 2D de supervivencia por hordas, construido con Flutter y
Flame. Usa primitivas dibujadas en código; no necesita imágenes, fuentes ni
otros assets externos para arrancar.

## Requisitos

- Flutter 3.32 o posterior, con Dart 3.8 o posterior.
- Un destino configurado en Flutter (Android, iOS, web o escritorio).

Las versiones principales están declaradas en `pubspec.yaml`: Flame `^1.32.0`
y `flutter_lints` `^6.0.0`.

## Preparar y ejecutar

Desde la raíz del proyecto:

```sh
flutter pub get
flutter run
```

También puedes seleccionar explícitamente un dispositivo, por ejemplo:

```sh
flutter devices
flutter run -d chrome
```

Para probar desde un teléfono conectado a la misma red Wi-Fi, inicia el
servidor web escuchando en la dirección de red del ordenador:

```sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Abre `http://<IP-local-del-ordenador>:8080` en el navegador del teléfono.
Permite la conexión de Flutter en el firewall de Windows si lo solicita.

Este starter contiene el código Dart y la configuración del paquete, pero no
incluye los proyectos nativos generados por el SDK. Si falta la carpeta de
plataforma del destino elegido, genera los runners una vez desde la raíz del
proyecto, por ejemplo:

```sh
flutter create --platforms=android,ios,web,windows --project-name survivors_arena .
flutter pub get
flutter run
```

Para ejecutar las pruebas y el analizador:

```sh
flutter test
flutter analyze
```

## Versión LÖVE y Lua

También hay un port independiente en `love/`. No sustituye ni modifica la app
Flutter. Instala LÖVE para Windows desde [love2d.org](https://love2d.org/) y,
desde la raíz del repositorio, ejecuta:

```powershell
love .\love
```

Lua ya viene incluido con LÖVE; no hace falta instalarlo por separado. Si el
comando `love` no está en el `PATH`, abre la carpeta `love` y arrástrala sobre
`love.exe`, o ejecuta LÖVE indicando la ruta completa al ejecutable.

En el menú, pulsa **Enter** o **Iniciar partida**. Durante la partida usa
**WASD** para moverte y mantén el clic izquierdo apuntando con el ratón para
lanzar piedras. En una pantalla táctil, usa los dos joysticks. Pulsa **R** para
reiniciar después de perder y **Escape** para volver al menú.

## Controles y prototipo

Pulsa **Iniciar partida** para entrar en el bosque. El personaje es un niño:
usa el joystick izquierdo para moverse y el derecho para apuntar y lanzar
piedras; mientras mantengas una dirección activa, lanza piedras repetidamente
hacia allí. La horda es pequeña: aparecen como máximo cuatro enemigos y lo
hacen cada cuatro segundos. Disparan proyectiles de miedo que puedes esquivar.
Cada impacto llena la barra; al llegar al 100 % pierdes. El HUD muestra el
tiempo y el miedo.

Personaje, enemigos y árboles se muestran inicialmente como hitboxes. El punto
inferior central de cada hitbox es su posición de referencia y determina su
orden de dibujo de Flame: los objetos con una base más abajo en pantalla se
dibujan por encima de los que están más arriba, y pasan detrás de los árboles
cuando su base queda antes que la del árbol. La colisión del árbol se limita a
la zona de los pies y el tronco; se puede caminar bajo la copa sin que esta
bloquee el paso.

## Estructura

```text
lib/
  main.dart
  screens/
    home_screen.dart
    game_screen.dart
  game/
    survivors_game.dart
    components/
      player.dart
      enemy.dart
      fear_projectile.dart
      stone_projectile.dart
      forest_background.dart
      hitbox_component.dart
      tree.dart
    widgets/
      hud_overlay.dart
      game_over_overlay.dart
      virtual_joystick_overlay.dart
test/
  game/
    survivors_game_test.dart
  widget_test.dart
```

## Ideas para extenderlo

- Separar estadísticas, estados de partida y configuración en modelos propios.
- Añadir ataques automáticos, proyectiles, experiencia y mejoras.
- Crear oleadas y tipos de enemigo reutilizando componentes de Flame.
- Incorporar persistencia, audio, menús de pausa y pruebas de lógica de juego.
- Añadir arte y animaciones propios cuando el prototipo ya tenga sus sistemas.
