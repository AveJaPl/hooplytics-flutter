# Hooplytics – Twoje centrum statystyk rzutowych 🏀

Hooplytics to nowoczesna aplikacja mobilna stworzona dla koszykarzy, którzy chcą precyzyjnie śledzić swoje postępy rzutowe. Projekt został przepisany z Next.js na **Flutter**, aby zapewnić płynne działanie na iOS, Androidzie, Windowsie oraz w przeglądarce.

---

## 🚀 Aktualne Funkcje

- **Konfiguracja Sesji**: Wybierz dystans (np. rzuty wolne, trójki) oraz konkretną pozycję na boisku.
- **Inteligentne Śledzenie**:
    - **Ręczne wprowadzanie**: Intuicyjne przyciski +/- do szybkiego zapisu trafień i pudła.
    - **Sterowanie Głosowe (PL)**: Tryb "hands-free" – mów "punkt" lub "pudło" podczas rzutu, a aplikacja sama zaktualizuje statystyki.
- **Baza Danych**: Wszystkie sesje są zapisywane lokalnie (SQLite), dzięki czemu masz dostęp do swojej historii treningów nawet bez internetu.
- **Premium Design**: Ciemny, sportowy motyw (Dark Mode) z dynamicznymi akcentami i nowoczesną typografią.

---

## 🛠️ Technologie

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Baza danych**: Sqflite
- **Rozpoznawanie mowy**: `speech_to_text` (optymalizowane pod język polski)
- **Design**: Google Fonts (Outfit), Material 3

---

## 📋 Instrukcja Uruchomienia

1. Upewnij się, że masz zainstalowanego Fluttera (`flutter doctor`).
2. Sklonuj repozytorium.
3. Pobierz zależności:
   ```bash
   flutter pub get
   ```
4. Uruchom aplikację:
   ```bash
   flutter run
   ```

---

## 🗺️ Mapa Drogowa (Future Works)

W kolejnych etapach planujemy dodać:

### 1. Rozbudowane Statystyki
- Wykresy skuteczności w czasie.
- "Heatmapa" boiska pokazująca, z których miejsc rzucasz najlepiej.
- Średnie tygodniowe i miesięczne progresu.

### 2. Gry i Wyzwania
- Tryby treningowe (np. "Around the World", "Pressure Free Throws").
- System poziomów i odznak za regularne treningi.

### 3. Synchronizacja w Chmurze
- Integracja z Firebase w celu synchronizacji danych między wieloma urządzeniami.
- Rankingi (Leaderboards) – porównuj swoje wyniki ze znajomymi.

### 4. Analiza Wideo (AI)
- W przyszłości: automatyczne rozpoznawanie trafień przy użyciu kamery i sztucznej inteligencji.

---

## 🤝 Wsparcie i Rozwój

Projekt jest w fazie intensywnego rozwoju. Jeśli masz pomysły na nowe funkcje lub znalazłeś błąd – otwórz Issue lub zadaj pytanie bezpośrednio!

**Hooplytics – Make every shot count.**
