# Detector digital de actividad EMG (MAV64) — Silicluster v3

Proyecto de circuito integrado digital en **SKY130 CMOS (1.8 V)** para detectar actividad muscular a partir de muestras EMG digitalizadas. Es una etapa de procesamiento digital: **requiere un ADC externo** y no incorpora amplificador analógico, ADC ni clasificador de gestos.

Desarrollado como parte de una línea de investigación en **circuitos integrados y procesamiento de señales biomédicas**, orientada a sistemas portátiles de adquisición EMG.

## ¿Qué hace el circuito?

Recibe muestras de **12 bits** a través de un bus físico de **8 bits** (transferencia en dos bytes), resta un offset configurable, calcula el valor absoluto y acumula **64 muestras** para obtener el **valor absoluto medio (MAV)**:

```text
ADC externo (12 bits)
        ↓
Interfaz digital de 8 bits (dos escrituras por muestra)
        ↓
Corrección de offset → valor absoluto
        ↓
Acumulación de 64 muestras → MAV = suma / 64
        ↓
Dos umbrales con histéresis
        ↓
activity = 1 (actividad) / 0 (reposo)
```

Los parámetros iniciales son `offset = 1995`, `threshold_low = 10` y `threshold_high = 16` (códigos de ADC). **Son valores de demostración**, no umbrales universales para cualquier persona o sistema de electrodos.

## Interfaz

Módulo principal: **`silicluster_emg_top`**. Alimentación nominal de la tecnología: **1.8 V**; `clk` y `rst` son externos (`rst` activo en alto).

| Entradas digitales (14) | Descripción |
| --- | --- |
| `data_in[7:0]` | Byte de datos o comando |
| `write_strobe` | Escritura por flanco ascendente (liberar entre escrituras) |
| `command_mode` | `1`: comando; `0`: dato |
| `view[1:0]` | Selección de dato para lectura |
| `byte_select` | Selección de byte bajo/alto de lectura |
| `enable` | Habilita recepción de transacciones |

| Salidas digitales (13) | Descripción |
| --- | --- |
| `data_out[7:0]` | Lectura multiplexada de resultado |
| `activity` | Actividad detectada por histéresis |
| `result_toggle` | Cambia al terminar cada ventana MAV64 |
| `ack_toggle` | Cambia al aceptar cada evento de escritura |
| `data_valid` | Hay al menos un resultado de ventana válido |
| `error_flag` | Comando o configuración inválidos |

**Comandos** (`command_mode=1`): `0` prepara escritura de muestra; `1`, offset; `2`, umbral bajo; `3`, umbral alto; `4`, captura lectura (*snapshot*); `5`, limpia el indicador de error. Cada valor de 12 bits se envía con dos escrituras (`command_mode=0`): byte bajo, seguido del nibble alto en `data_in[3:0]` (los cuatro bits superiores deben valer cero). Para leer: comando `4`, `view=00` señal centrada, `01` magnitud, `10` MAV, `11` estado; usar `byte_select` para elegir byte.

## Validación realizada

- Simulación RTL con **Icarus Verilog** y síntesis lógica con **Yosys**.
- Pruebas con **16,000 muestras EMG reales**: 8,000 de reposo y 8,000 de cierre de mano. **250 ventanas de 64 muestras** coincidieron con la referencia matemática del testbench.
- Para los umbrales de demostración: 0/125 ventanas activas en reposo y 111/125 en el registro de cierre. Esta proporción **no representa exactitud clínica ni clasificación de gestos**.
- Implementación física preliminar con **LibreLane 3.0.17 / SKY130** a **10 MHz**, dentro del área de proyecto **180 × 115 µm**; DRC/LVS y setup/hold completados en la ejecución revisada.
- La mejor configuración física exploratoria fue **core 170 × 105 µm** y `MAX_FANOUT_CONSTRAINT=6`: **23 violaciones Max Slew residuales** en la esquina lenta. No se afirma que el circuito fabricado esté validado; estas advertencias siguen abiertas.

## Archivos principales

| Ruta | Contenido |
| --- | --- |
| `silicluster_emg_top.v` | Interfaz del chip para Silicluster |
| `silicluster_emg_core.v` | Lógica MAV64, umbrales y registros |
| `tb_silicluster.v` | Pruebas funcionales básicas |
| `tb_emg_real.v` | Comparación contra referencia con registros EMG |
| `test/*.hex` | Dos registros de prueba de 8,000 muestras |
| `physical/config.json` | Configuración base para LibreLane (no es la configuración experimental de fanout 6) |
| `.github/workflows/` | Simulación, síntesis, entrega e implementación física |
| `submission/Silicluster_v3_EMG_MAV64_Digital.zip` | Paquete de entrega con código y pruebas |

### Ejecutar pruebas RTL localmente

Con Icarus Verilog instalado, desde la raíz del repositorio:

```bash
iverilog -g2005 -s tb_silicluster -o basic.vvp silicluster_emg_core.v silicluster_emg_top.v tb_silicluster.v
vvp -n basic.vvp
iverilog -g2012 -s tb_emg_real -o emg.vvp silicluster_emg_core.v silicluster_emg_top.v tb_emg_real.v
vvp -n emg.vvp
```

También es posible ejecutar los workflows en **GitHub → Actions**. El flujo físico base está en `silicluster-physical.yml`; el experimento de **fanout 6** está en `silicluster-slew-experiment.yml` y **no modifica permanentemente** `physical/config.json`.

## Videos y proyecto relacionado

- [Video compartido del proyecto (YouTube)](https://youtu.be/Es1mF6aPttk) — material de contexto.
- [Apertura y cierre de una mano robótica, modelo Franco R4](media/Mano_Franco_R4_apertura_cierre.mp4) — demostración mecánica relacionada con posibles aplicaciones futuras.

**Aclaración:** los videos y la mano robótica contextualizan la línea de trabajo; **no constituyen una demostración de un chip Silicluster fabricado ni de una conexión entre el MAV64 y la mano**.

## Alcance

Este repositorio contiene el **bloque digital de detección de actividad de un canal EMG**. Los diseños de adquisición analógica, PCB del sistema de electrodos, la red neuronal de clasificación y los archivos de impresión 3D forman parte de trabajos relacionados, pero **no se requieren para sintetizar este circuito**. El siguiente objetivo experimental es comparar este bloque en silicio con las mediciones y los resultados RTL.

**Autor:** Eduardo Franco Delgado Pérez · Facultad de Ciencias de la Electrónica, BUAP.
