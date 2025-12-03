protocol EmptyRepresentable {
  var isEmpty: Bool { get }
  var presence: Self? { get }
}

extension EmptyRepresentable {
  var presence: Self? { isEmpty ? nil : self }
}

extension String: EmptyRepresentable {}
extension Array: EmptyRepresentable {}
