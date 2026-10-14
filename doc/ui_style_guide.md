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

### Section surfaces and status summaries

Use one page inset around a form. Place section surfaces directly within that
inset, with aligned outside edges and `kSectionGap` between sections. Avoid a
padded surface around the whole page when its sections already have surfaces;
that doubles the inset and makes the content feel unnecessarily narrow. Each
section surface owns its `kPageInset` interior padding.

For grouped line items, use one surface per group with a distinct heading band
and dividers between rows. Keep group headings attached to their rows, and use
`kFieldGap` between groups. Do not give every row another inset surface. Retain
editing controls and meaningful line states within the rows.

Combine related status information into one section: a heading and `HMBChip`
for the business status, a prominent relevant amount, supporting totals, and
one plain-language tracking or integration state. Omit labels that merely
repeat an implication of another state, such as linked alongside synced.
An optional integration being unconfigured is not itself an error. Describe
the available workflow, such as “Payments tracked in HMB”. Preserve actionable
warnings when an existing integration or tracking mode needs attention.

History rows should show the event, amount, and relevant date. For invoice
payments, use “Received” and the receipt date where available. Keep internal
IDs, placeholder UUIDs, and provider plumbing out of these summaries. Retain
human-readable reasons for credits and adjustments. Allow rows, status chips,
and amounts to wrap at narrow widths and large text sizes.

The invoice editor in `lib/ui/invoicing/edit_invoice_screen.dart` demonstrates
this layout.

### Shared controls

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
