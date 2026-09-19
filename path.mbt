///|
/// One segment in an RFC 6901 JSON Pointer.
pub(all) enum PathSegment {
  Property(String)
  Index(Int)
} derive(Eq, Debug)

///|
/// An immutable path into either a schema or an instance document.
pub(all) struct JsonPointer {
  segments : Array[PathSegment]
} derive(Eq, Debug)

///|
pub fn JsonPointer::root() -> JsonPointer {
  { segments: [], }
}

///|
pub fn JsonPointer::property(self : JsonPointer, name : String) -> JsonPointer {
  let next = self.segments.copy()
  next.push(Property(name))
  { segments: next, }
}

///|
pub fn JsonPointer::index(self : JsonPointer, index : Int) -> JsonPointer {
  let next = self.segments.copy()
  next.push(Index(index))
  { segments: next, }
}

///|
pub fn JsonPointer::parent(self : JsonPointer) -> JsonPointer? {
  if self.segments.is_empty() {
    None
  } else {
    let next : Array[PathSegment] = []
    for index, segment in self.segments {
      if index + 1 < self.segments.length() {
        next.push(segment)
      }
    }
    Some({ segments: next, })
  }
}

///|
pub fn JsonPointer::depth(self : JsonPointer) -> Int {
  self.segments.length()
}

///|
pub fn JsonPointer::is_root(self : JsonPointer) -> Bool {
  self.segments.is_empty()
}

///|
fn pointer_escape(text : String) -> String {
  let output = StringBuilder()
  for character in text {
    match character {
      '~' => output.write_string("~0")
      '/' => output.write_string("~1")
      _ => output.write_char(character)
    }
  }
  output.to_string()
}

///|
pub fn JsonPointer::to_string(self : JsonPointer) -> String {
  let output = StringBuilder()
  for segment in self.segments {
    output.write_char('/')
    match segment {
      Property(name) => output.write_string(pointer_escape(name))
      Index(index) => output.write_string(index.to_string())
    }
  }
  output.to_string()
}

///|
pub fn JsonPointer::display(self : JsonPointer) -> String {
  if self.is_root() {
    "<root>"
  } else {
    self.to_string()
  }
}

///|
pub fn JsonPointer::segments_copy(self : JsonPointer) -> Array[PathSegment] {
  self.segments.copy()
}

///|
pub fn JsonPointer::append(
  self : JsonPointer,
  suffix : JsonPointer,
) -> JsonPointer {
  let next = self.segments.copy()
  for segment in suffix.segments {
    next.push(segment)
  }
  { segments: next, }
}

///|
pub fn JsonPointer::last_property(self : JsonPointer) -> String? {
  if self.segments.is_empty() {
    None
  } else {
    match self.segments[self.segments.length() - 1] {
      Property(name) => Some(name)
      Index(_) => None
    }
  }
}

///|
pub fn JsonPointer::last_index(self : JsonPointer) -> Int? {
  if self.segments.is_empty() {
    None
  } else {
    match self.segments[self.segments.length() - 1] {
      Index(index) => Some(index)
      Property(_) => None
    }
  }
}
