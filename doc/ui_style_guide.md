# HMB UI style guide

Use the shared controls in `lib/ui/widgets/` when building or changing a
screen. The runnable reference is `tool/style_preview.dart`; launch it with
`flutter run -t tool/style_preview.dart`. It uses fictional data and does not
open the application database.

## Spacing and form layout

All dimensions are logical pixels. The source of truth is `HMBSpacing` in
`lib/ui/widgets/layout/hmb_spacing.dart`.

| Space | Constant | Use |
| --- | --- | --- |
| 8 | `kCompact` | Related summary lines, icon/label groups, compact stacks |
| 12 | `kRelated` | Related controls laid out horizontally |
| 16 | `kFieldGap` | Between form fields, selectors, toggles and action groups |
| 24 | `kSectionGap` | Between separate form sections or summary panels |
| 16 | `kPageInset` | Form page edges and form panel interiors |

Use `HMBFormSection` for related fields. It stretches controls to the available
width, wraps its content vertically and puts 16 pixels **between** children.
It adds no outside padding by default. Its `leadingSpace` option explicitly
adds one field gap above the group when required.

Use `HMBFormList` for a standalone scrolling form. It supplies 16-pixel page
insets and field gaps, and builds list children lazily. Set
`spacing: HMBSpacing.kSectionGap` when the children are whole sections.
`EntityEditScreen` and `NestedEntityEditScreen` already provide scrolling and
page insets; their editors should return a section, not another padded list.

The parent owns spacing between children. Do not add spacer widgets or bottom
margins between children of these form layouts. A nested section supplies only
its internal gaps, so it does not double the gap to the next section. Group
summary lines in an `HMBColumn`, whose compact 8-pixel default is intentional.
Keep explanatory text beside its related control; separate unrelated groups
with a heading and the section gap. Avoid a flat wall of labels and controls.

```dart
HMBFormList(
  spacing: HMBSpacing.kSectionGap,
  children: [
    HMBFormSection(children: [nameField, descriptionField]),
    Surface(
      padding: const EdgeInsets.all(HMBSpacing.kPageInset),
      child: HMBFormSection(children: [billingHeading, rateField, taxField]),
    ),
    saveAndCancel,
  ],
)
```

## Shared visual elements

| Need | Shared implementation |
| --- | --- |
| Theme, colours, borders and typography | `HMBTheme.dark`, `HMBColors` |
| Text, money, integer, email and phone input | `HMBTextField`, `HMBTextArea`, `HMBMoneyField`, `HMBIntegerField`, `HMBEmailField`, `HMBPhoneField` |
| Searchable choices and entity selection | `HMBDroplist`, `HMBSelect…` widgets |
| Boolean choices | `HMBToggle`, `HMBSwitch` |
| Primary and secondary actions | `HMBButtonPrimary`, `HMBButtonSecondary` |
| Save/cancel actions | `HMBSaveCancelButtons`, `SaveAndClose` |
| Status and menus | `HMBChip`, `HMBMenuChip` |
| Grouped content | `Surface`, `SurfaceCardWithActions`, `LabeledContainer` |
| Compact content and rows | `HMBColumn`, `HMBRow` |
| Form groups and scrolling forms | `HMBFormSection`, `HMBFormList` |
| Child pages and dialogs | `HMBFullPageChildScreen`, `HMBDialog` |
| Async waiting | `BlockingUI`, shared `BlockingOverlay` |

The theme uses charcoal surfaces, lavender actions, subtle outlines and rounded
corners. Use theme text styles for headings, body text and secondary detail.
A page title uses the app bar; section headings use `titleMedium` or the shared
heading widgets. Body text should wrap naturally. Avoid hard-coded text colours
and fixed text heights. Validation belongs to the field; retain its error text
and let the following controls move down when an error is shown.

Use one clear primary action per action group. Secondary actions use the shared
secondary button. Keep accessible touch targets and descriptive tooltips for
icon-only actions. Use wrapping button groups on narrow screens instead of
forcing long labels into a fixed row.

## Responsive and async behaviour

Forms must scroll with the keyboard open and with text scaled to 200%. Let
controls grow with labels and validation text. Do not reduce field gaps on
small screens to fit more controls. Prefer one field per row on phones; use
`Expanded` or wrapping layouts for related fields when a row is appropriate.
A child screen can use `maxContentWidth` to bound a wide desktop form.

Use `DeferredState.asyncInitState` and `DeferredBuilder` for asynchronous
initialization. Use `FutureBuilderEx` with explicit waiting/error builders for
asynchronous content. The application-level `BlockingOverlay` supplies waiting
feedback; do not introduce local loading dialogs or literal loading text.

## Review checklist

- Use the same field and section spacing for full pages, dialogs and wizard
  steps. Wizards reuse the system settings forms.
- Check a 320-pixel viewport and 200% text scale; scroll to the final action.
- Exercise validation and conditional fields so added content remains readable.
- Inspect screenshots of the affected screens and the shared style preview.
- Run the focused widget tests, `flutter test` and `flutter analyze`.
