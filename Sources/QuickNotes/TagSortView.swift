import SwiftUI

struct TagSortView: View {
  @EnvironmentObject var vm: NotesViewModel
  @Binding var isPresented: Bool
  @State private var sortableTags: [String] = []
  @State private var draggedTag: String?

  var body: some View {
    AppSheet(
      title: "Reorder Tags",
      primaryActionTitle: "Save",
      minHeight: 400,
      closeAction: { isPresented = false },
      cancelAction: cancel,
      primaryAction: save
    ) {
      ScrollView {
        LazyVStack(spacing: AppSpacing.small) {
          if sortableTags.isEmpty {
            Text("No tags available to reorder.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.vertical, 32)
          } else {
            ForEach(sortableTags, id: \.self) { tag in
              TagSortRow(
                tag: tag,
                isDragged: draggedTag == tag,
                onDragStart: { draggedTag = tag }
              )
              .onDrop(of: [.text], delegate: TagDropDelegate(
                tag: tag,
                tags: $sortableTags,
                draggedTag: $draggedTag
              ))
            }
          }
        }
        .padding(AppSpacing.medium)
      }
      .frame(minHeight: 160, maxHeight: 300)
      .background(AppTheme.surface)
      .clipShape(.rect(cornerRadius: 9))
      .overlay {
        RoundedRectangle(cornerRadius: 9)
          .stroke(AppTheme.border)
      }
    }
    .onAppear {
      sortableTags = vm.tags.filter { $0 != vm.clipboardTag }
    }
  }

  private func save() {
    vm.updateTagsOrder(sortableTags)
    isPresented = false
  }

  private func cancel() {
    sortableTags = vm.tags.filter { $0 != vm.clipboardTag }
    isPresented = false
  }
}

struct TagSortRow: View {
  let tag: String
  let isDragged: Bool
  let onDragStart: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "tag.fill")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.brandBlue)

      Text(tag)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)

      Spacer()

      Image(systemName: "line.3.horizontal")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, AppSpacing.medium)
    .padding(.vertical, 10)
    .background(isDragged ? AppTheme.selectedFill : AppTheme.elevatedSurface)
    .clipShape(.rect(cornerRadius: 7))
    .overlay {
      RoundedRectangle(cornerRadius: 7)
        .stroke(isDragged ? AppTheme.brandBlue.opacity(0.55) : AppTheme.border)
    }
    .opacity(isDragged ? 0.82 : 1.0)
    .scaleEffect(isDragged ? 1.015 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: isDragged)
    .onDrag {
      onDragStart()
      return NSItemProvider(object: tag as NSString)
    }
  }
}

struct TagDropDelegate: DropDelegate {
  let tag: String
  @Binding var tags: [String]
  @Binding var draggedTag: String?

  func performDrop(info: DropInfo) -> Bool {
    guard let draggedTag = draggedTag else { return false }

    if draggedTag != tag {
      let fromIndex = tags.firstIndex(of: draggedTag) ?? 0
      let toIndex = tags.firstIndex(of: tag) ?? 0

      if fromIndex != toIndex {
        tags.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
      }
    }

    self.draggedTag = nil
    return true
  }

  func dropEntered(info: DropInfo) {
    guard let draggedTag = draggedTag else { return }

    if draggedTag != tag {
      let fromIndex = tags.firstIndex(of: draggedTag) ?? 0
      let toIndex = tags.firstIndex(of: tag) ?? 0

      if fromIndex != toIndex {
        withAnimation(.default) {
          tags.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
      }
    }
  }
}
