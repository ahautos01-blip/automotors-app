import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import '../services/vehicle_search.dart';
import 'market_theme.dart';

class MarketComparisonCar {
  final String title, price;
  final int year;
  final Uint8List? photo;
  const MarketComparisonCar({
    required this.title,
    required this.price,
    required this.year,
    this.photo,
  });
}

class MarketComparisonField {
  final String label;
  final List<String?> values;
  final bool equipment;
  const MarketComparisonField(
    this.label,
    this.values, {
    this.equipment = false,
  });
  bool get differs =>
      values
          .map((v) => v == null ? '' : normalizeVehicleSearch(v))
          .toSet()
          .length >
      1;
}

class MarketComparisonView extends StatefulWidget {
  final List<MarketComparisonCar> cars;
  final List<MarketComparisonField> fields;
  final ValueChanged<int>? onOpen;
  const MarketComparisonView({
    super.key,
    required this.cars,
    required this.fields,
    this.onOpen,
  });
  @override
  State<MarketComparisonView> createState() => _MarketComparisonViewState();
}

class _MarketComparisonViewState extends State<MarketComparisonView> {
  bool differencesOnly = false;
  final horizontal = ScrollController();
  final vertical = ScrollController();
  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final differences = widget.fields.where((field) => field.differs).length;
    final visible = widget.fields
        .where((field) => !differencesOnly || field.differs)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(uiText(context, 'Comparar vehículos'))),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                uiText(
                  context,
                  'Datos publicados. “No indicado” no significa que el vehículo no lo tenga.',
                ),
                style: const TextStyle(
                  color: marketMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            SwitchListTile.adaptive(
              key: const Key('comparison-differences-toggle'),
              title: Text(uiText(context, 'Solo diferencias')),
              subtitle: Text(
                uiText(context, '{0} campos diferentes', [differences]),
              ),
              value: differencesOnly,
              onChanged: (value) => setState(() => differencesOnly = value),
              activeTrackColor: marketAccent,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.max(
                    constraints.maxWidth,
                    widget.cars.length * 144.0 + 24,
                  );
                  final canScroll = width > constraints.maxWidth + 1;
                  return Column(
                    children: [
                      if (canScroll)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            uiText(
                              context,
                              'Desliza para ver todos los vehículos',
                            ),
                            style: const TextStyle(
                              color: marketMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Scrollbar(
                          controller: horizontal,
                          thumbVisibility: canScroll,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: horizontal,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: width,
                              child: Column(
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: math.max(
                                        48,
                                        (constraints.maxHeight -
                                                (canScroll ? 30 : 0)) *
                                            .55,
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          10,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            for (
                                              var index = 0;
                                              index < widget.cars.length;
                                              index++
                                            )
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  child: Material(
                                                    color: marketSurface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          15,
                                                        ),
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    child: InkWell(
                                                      key: ValueKey(
                                                        'comparison-car-$index',
                                                      ),
                                                      onTap:
                                                          widget.onOpen == null
                                                          ? null
                                                          : () =>
                                                                widget.onOpen!(
                                                                  index,
                                                                ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          if (constraints
                                                                  .maxHeight >
                                                              400)
                                                            SizedBox(
                                                              height: 78,
                                                              child:
                                                                  widget
                                                                          .cars[index]
                                                                          .photo ==
                                                                      null
                                                                  ? const ColoredBox(
                                                                      color:
                                                                          marketTint,
                                                                      child: Icon(
                                                                        Icons
                                                                            .directions_car_outlined,
                                                                        color:
                                                                            marketMuted,
                                                                      ),
                                                                    )
                                                                  : Image.memory(
                                                                      widget
                                                                          .cars[index]
                                                                          .photo!,
                                                                      fit: BoxFit
                                                                          .cover,
                                                                      errorBuilder: (_, error, stack) => const ColoredBox(
                                                                        color:
                                                                            marketTint,
                                                                        child: Icon(
                                                                          Icons
                                                                              .directions_car_outlined,
                                                                          color:
                                                                              marketMuted,
                                                                        ),
                                                                      ),
                                                                    ),
                                                            ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  10,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  widget
                                                                      .cars[index]
                                                                      .title,
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    height: 1.2,
                                                                  ),
                                                                ),
                                                                if (widget
                                                                        .cars[index]
                                                                        .year >
                                                                    0)
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          top:
                                                                              4,
                                                                        ),
                                                                    child: Text(
                                                                      '${widget.cars[index].year}',
                                                                      style: const TextStyle(
                                                                        color:
                                                                            marketMuted,
                                                                        fontSize:
                                                                            11,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Text(
                                                                  widget
                                                                      .cars[index]
                                                                      .price,
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    fontSize:
                                                                        16,
                                                                  ),
                                                                ),
                                                                if (widget
                                                                        .onOpen !=
                                                                    null)
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          top:
                                                                              6,
                                                                        ),
                                                                    child: Text(
                                                                      uiText(
                                                                        context,
                                                                        'Ver anuncio',
                                                                      ),
                                                                      style: const TextStyle(
                                                                        color:
                                                                            marketAccent,
                                                                        fontSize:
                                                                            11,
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: visible.isEmpty
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Text(
                                                uiText(
                                                  context,
                                                  'No hay diferencias en los datos publicados.',
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          )
                                        : ListView.builder(
                                            controller: vertical,
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            itemCount: visible.length,
                                            itemBuilder: (context, index) {
                                              final field = visible[index];
                                              return Container(
                                                key: ValueKey(
                                                  'comparison-field-${field.label}',
                                                ),
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      12,
                                                      16,
                                                      14,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: field.differs
                                                      ? marketTint
                                                      : marketPaper,
                                                  border: const Border(
                                                    bottom: BorderSide(
                                                      color: marketLine,
                                                    ),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            uiText(
                                                              context,
                                                              field.label,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                        if (field.differs)
                                                          Icon(
                                                            Icons
                                                                .compare_arrows_rounded,
                                                            color: marketAccent,
                                                            size: 18,
                                                            semanticLabel:
                                                                uiText(
                                                                  context,
                                                                  'Diferente',
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        for (final value
                                                            in field.values)
                                                          Expanded(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              child: Text(
                                                                value == null
                                                                    ? uiText(
                                                                        context,
                                                                        'No indicado',
                                                                      )
                                                                    : uiText(
                                                                        context,
                                                                        value,
                                                                      ),
                                                                style: TextStyle(
                                                                  color:
                                                                      value ==
                                                                          null
                                                                      ? marketMuted
                                                                      : marketInk,
                                                                  fontSize: 13,
                                                                  height: 1.4,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
