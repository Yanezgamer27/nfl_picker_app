import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NFLPickerApp());
}

class NFLPickerApp extends StatelessWidget {
  const NFLPickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFL Picker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 4,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentWeek = 2;
  List<dynamic> games = [];
  Map<String, String> userPicks = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchESPNData();
  }

  Future<void> fetchESPNData() async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse(
        'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?week=$currentWeek');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List<dynamic>;

        if (!mounted) return;

        setState(() {
          games = events.map((event) {
            final competition = event['competitions'][0];
            final competitors = competition['competitors'] as List<dynamic>;
            final home = competitors.firstWhere((c) => c['homeAway'] == 'home');
            final away = competitors.firstWhere((c) => c['homeAway'] == 'away');
            final isCompleted = event['status']['type']['completed'] ?? false;

            String? winner;
            if (isCompleted) {
              int homeScore = int.tryParse(home['score'].toString()) ?? 0;
              int awayScore = int.tryParse(away['score'].toString()) ?? 0;
              if (homeScore > awayScore) {
                winner = home['team']['abbreviation'];
              } else if (awayScore > homeScore) {
                winner = away['team']['abbreviation'];
              } else {
                winner = 'EMPATE';
              }
            }

            return {
              'id': event['id'],
              'status': isCompleted
                  ? 'FINAL'
                  : (event['status']['type']['shortDetail'] ?? 'PRÓXIMAMENTE'),
              'isCompleted': isCompleted,
              'home': home['team']['abbreviation'],
              'homeScore': home['score'] ?? '0',
              'away': away['team']['abbreviation'],
              'awayScore': away['score'] ?? '0',
              'winner': winner,
            };
          }).toList();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener datos de ESPN')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void selectWinner(String gameId, String team, bool isCompleted) {
    if (isCompleted) return;
    setState(() {
      if (userPicks[gameId] == team) {
        userPicks.remove(gameId);
      } else {
        userPicks[gameId] = team;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int hits = 0;
    int completedPicked = 0;

    for (var game in games) {
      String gameId = game['id'].toString();
      String? selected = userPicks[gameId];
      if (game['isCompleted'] && selected != null) {
        completedPicked++;
        if (selected == game['winner']) {
          hits++;
        }
      }
    }

    int accuracy =
        completedPicked > 0 ? ((hits / completedPicked) * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NFL PICKER 🏈',
          style: TextStyle(
              color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          DropdownButton<int>(
            value: currentWeek,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(
                color: Colors.amber, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            items: List.generate(18, (index) => index + 1).map((week) {
              return DropdownMenuItem<int>(
                value: week,
                child: Text('Semana $week'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  currentWeek = value;
                });
                fetchESPNData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: fetchESPNData,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('ACIERTOS SEMANA',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$hits / $completedPicked',
                        style: const TextStyle(
                            color: Colors.lightGreenAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.white24),
                Column(
                  children: [
                    const Text('EFECTIVIDAD',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$accuracy%',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      final gameId = game['id'].toString();
                      final selected = userPicks[gameId];
                      final isCompleted = game['isCompleted'] as bool;
                      final isHit = isCompleted && selected == game['winner'];
                      final isMiss = isCompleted &&
                          selected != null &&
                          selected != game['winner'];

                      Color cardColor = const Color(0xFF1E293B);
                      Color borderColor = Colors.white10;

                      if (isHit) {
                        borderColor = Colors.green;
                        cardColor = Colors.green.withAlpha(25);
                      } else if (isMiss) {
                        borderColor = Colors.redAccent;
                        cardColor = Colors.redAccent.withAlpha(25);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '⏰ ${game['status']}',
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (isHit)
                                  const Text('✓ ACERTADO',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                if (isMiss)
                                  const Text('✕ FALLADO',
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTeamButton(
                                    gameId: gameId,
                                    team: game['away'],
                                    score: game['awayScore'],
                                    role: 'VISITA',
                                    selected: selected,
                                    game: game,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTeamButton(
                                    gameId: gameId,
                                    team: game['home'],
                                    score: game['homeScore'],
                                    role: 'LOCAL',
                                    selected: selected,
                                    game: game,
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
    );
  }

  Widget _buildTeamButton({
    required String gameId,
    required String team,
    required String score,
    required String role,
    required String? selected,
    required dynamic game,
  }) {
    bool isSelected = selected == team;
    bool isCompleted = game['isCompleted'];
    bool isWinner = game['winner'] == team;

    Color btnColor = const Color(0xFF0F172A);
    Color textColor = Colors.white;

    if (isCompleted) {
      if (isSelected && isWinner) {
        btnColor = Colors.green;
        textColor = Colors.black;
      } else if (isSelected && !isWinner) {
        btnColor = Colors.redAccent;
        textColor = Colors.white;
      } else if (isWinner) {
        btnColor = Colors.green.withAlpha(75);
      } else {
        btnColor = Colors.black26;
        textColor = Colors.grey;
      }
    } else if (isSelected) {
      btnColor = Colors.amber;
      textColor = Colors.black;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => selectWinner(gameId, team, isCompleted),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$team ($score)',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(role,
              style: TextStyle(
                  fontSize: 9, color: textColor.withAlpha(180))),
        ],
      ),
    );
  }
}