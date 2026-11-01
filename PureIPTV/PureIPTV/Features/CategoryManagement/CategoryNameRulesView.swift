import ComposableArchitecture
import SwiftUI

public struct CategoryNameRulesView: View {
    @Bindable var store: StoreOf<CategoryManagementFeature>

    public init(store: StoreOf<CategoryManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(AppStrings.CategoryMgmt.nameRulesDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(store.draftCategoryNameRules) { rule in
                    ruleSection(rule)
                }

                Section {
                    Button {
                        store.send(.addCategoryNameRuleTapped)
                    } label: {
                        Label(AppStrings.Common.add, systemImage: "plus")
                    }
                    .disabled(store.draftCategoryNameRules.count >= 100)
                }

                if store.categoryNameRuleSaveFailed {
                    Section {
                        Text(AppStrings.CategoryMgmt.nameRuleSaveFailed)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(AppStrings.CategoryMgmt.nameRulesTitle)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel) {
                            store.send(.cancelCategoryNameRulesTapped)
                        }
                        .disabled(store.isSavingCategoryNameRules)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) {
                            store.send(.saveCategoryNameRulesTapped)
                        }
                        .disabled(!store.hasCategoryNameRuleChanges || store.isSavingCategoryNameRules)
                    }
                }
                .interactiveDismissDisabled(store.isSavingCategoryNameRules)
        }
    }

    private func ruleSection(_ rule: CategoryNameRule) -> some View {
        let matches = CategoryNameRuleMatcher.matchingCategories(for: rule, in: store.originalCategories)

        return Section {
            Picker(
                AppStrings.CategoryMgmt.nameRuleMatchType,
                selection: modeBinding(for: rule)
            ) {
                Text(AppStrings.CategoryMgmt.nameRuleLiteral)
                    .tag(CategoryNameRule.MatchMode.literal)
                Text(AppStrings.CategoryMgmt.nameRuleRegularExpression)
                    .tag(CategoryNameRule.MatchMode.regularExpression)
            }

            TextField(AppStrings.CategoryMgmt.categoryName, text: patternBinding(for: rule))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(AppStrings.CategoryMgmt.categoryName)

            Toggle(
                AppStrings.CategoryMgmt.nameRuleEnabled,
                isOn: enabledBinding(for: rule)
            )

            if let issue = CategoryNameRuleMatcher.validationIssue(for: rule) {
                Text(validationMessage(for: issue))
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("\(matches.count) \(AppStrings.Common.results)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if matches.isEmpty {
                Text(AppStrings.Common.categoryNotFound)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches) { category in
                    Text(category.sourceName)
                        .lineLimit(2)
                }
            }

            Button(role: .destructive) {
                store.send(.removeCategoryNameRule(id: rule.id))
            } label: {
                Label(AppStrings.Common.delete, systemImage: "trash")
            }
        }
    }

    private func patternBinding(for rule: CategoryNameRule) -> Binding<String> {
        Binding(
            get: { store.draftCategoryNameRules.first(where: { $0.id == rule.id })?.pattern ?? "" },
            set: { store.send(.setCategoryNameRulePattern(id: rule.id, pattern: $0)) }
        )
    }

    private func modeBinding(for rule: CategoryNameRule) -> Binding<CategoryNameRule.MatchMode> {
        Binding(
            get: { store.draftCategoryNameRules.first(where: { $0.id == rule.id })?.mode ?? rule.mode },
            set: { store.send(.setCategoryNameRuleMode(id: rule.id, mode: $0)) }
        )
    }

    private func enabledBinding(for rule: CategoryNameRule) -> Binding<Bool> {
        Binding(
            get: { store.draftCategoryNameRules.first(where: { $0.id == rule.id })?.isEnabled ?? false },
            set: { _ in store.send(.toggleCategoryNameRule(id: rule.id)) }
        )
    }

    private func validationMessage(for issue: CategoryNameRuleMatcher.ValidationIssue) -> String {
        switch issue {
        case .emptyPattern, .patternTooLong, .invalidRegularExpression, .unsupportedRegularExpression:
            AppStrings.CategoryMgmt.nameRuleInvalidPattern
        }
    }
}
