# frozen_string_literal: true

module AccountHeader
  extend ActiveSupport::Concern

  IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/gif'].freeze

  class_methods do
    def header_styles(file)
      styles = { original: { geometry: '700x335#', file_geometry_parser: FastGeometryParser } }
      styles[:static] = { geometry: '700x335#', format: 'png', convert_options: '-coalesce', file_geometry_parser: FastGeometryParser } if file.content_type == 'image/gif'
      styles
    end

    private :header_styles
  end

  included do
    # Header upload
    has_attached_file :header, styles: ->(f) { header_styles(f) }, convert_options: { all: '-strip' }, processors: [:lazy_thumbnail]
    validates_attachment_content_type :header, content_type: IMAGE_MIME_TYPES
    validates_attachment_size :header, less_than: 2.megabytes
  end

  def header_original_url
    header.url(:original)
  end

  def header_static_url
    header_content_type == 'image/gif' ? header.url(:static) : header_original_url
  end
end
