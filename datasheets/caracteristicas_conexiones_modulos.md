# Características módulo NEO-6M
- Vcc (2.7V - 3.6V)
## Tiempo hasta primer posicionamiento
Tiempo hasta primer posicionamiento (Time-To-First-Fix, TTFF)
Se divide en tres modos principales, más el caso de arranque “ayudado” (Aided).

Cold Start (arranque en frío): El módulo no dispone de datos de efemérides (órbitas de satélites) ni reloj previo, ni conoce ni la última posición ni la hora. Requiere buscar y sincronizarse con satélites desde cero.

NEO-6M/V: 27 s

Warm Start (arranque en caliente/moderado): El módulo conserva datos de efemérides suficientemente recientes para evitar descargar toda la información de satélites, pero no dispone de la posición exacta ni del tiempo con alta precisión.

NEO-6M/V: 27 s

Hot Start (arranque rápido): El módulo aún retiene posición aproximada, reloj interno y efemérides válidas (p. ej., si se reinicia tras un breve apagado).

Todos los modelos (G/Q/T/M/V/P): 1 s

Aided Starts (arranque “ayudado”): Cuando el receptor recibe datos de efemérides y posición por un canal externo (por ejemplo, a través de AssistNow o “supl”), el TTFF se reduce aún más.

NEO-6G/Q/T: 1 s

NEO-6M/V: < 3 s

NEO-6P: < 3 s 

## Frecuencia máxima de actualización de navegación (Maximum Navigation update rate)

NEO-6G/Q/M/T: hasta 5 Hz, es decir, el módulo puede entregar hasta cinco posiciones por segundo.

## Exactitud horizontal de posición (Horizontal position accuracy)
Se indica la precisión radial esperada (con un nivel de confianza del 50% o R50) bajo diversas condiciones:

GPS (solo señal GPS): 2.5 m (50% de las veces el error radial será menor a 2.5 m).

SBAS: 2.0 m (al usar correcciones de sistemas SBAS, mejora la precisión).

SBAS + PPP (Precise Point Positioning) – solo en NEO-6P:

< 1 m (2D, R50): en dos dimensiones (latitud/longitud), 50% de las lecturas estarán dentro de 1 m.

< 2 m (3D, R50): en tres dimensiones (latitud/longitud/altitud), 50% de las lecturas estarán dentro de 2 m.

## Límites operacionales (Operational Limits)
Condiciones bajo las cuales el receptor puede funcionar correctamente sin degradar su desempeño debido a movimiento o altitud excesiva:

Dinámica (Dynamics): máximo < 4 g de aceleración. El módulo tolera aceleraciones de hasta 4 g (alineadas con la orientación esperada) y sigue calculando la posición sin caída de señal.

Altitud (Altitude): hasta 50 000 m (50 km). Si el receptor se utiliza a altitudes por encima de 50 km, el desempeño no está garantizado (es raro en aplicaciones civiles; cubre prácticamente cualquier avión comercial o drones de gran altitud).

Velocidad (Velocity): hasta 500 m/s (≈ 1 800 km/h). Cubre la mayoría de aviones civiles e incluso algunos aviones militares de velocidad moderada. NEO-6_DataSheet_(GPS.G6…

