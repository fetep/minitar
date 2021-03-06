# coding: utf-8

module Archive
  module Tar
    module Minitar
      # Implements the POSIX tar header as a Ruby class. The structure of
      # the POSIX tar header is:
      #
      #   struct tarfile_entry_posix
      #   {                      //                               pack/unpack
      #      char name[100];     // ASCII (+ Z unless filled)     a100/Z100
      #      char mode[8];       // 0 padded, octal, null         a8  /A8
      #      char uid[8];        // 0 padded, octal, null         a8  /A8
      #      char gid[8];        // 0 padded, octal, null         a8  /A8
      #      char size[12];      // 0 padded, octal, null         a12 /A12
      #      char mtime[12];     // 0 padded, octal, null         a12 /A12
      #      char checksum[8];   // 0 padded, octal, null, space  a8  /A8
      #      char typeflag[1];   // see below                     a   /a
      #      char linkname[100]; // ASCII + (Z unless filled)     a100/Z100
      #      char magic[6];      // "ustar\0"                     a6  /A6
      #      char version[2];    // "00"                          a2  /A2
      #      char uname[32];     // ASCIIZ                        a32 /Z32
      #      char gname[32];     // ASCIIZ                        a32 /Z32
      #      char devmajor[8];   // 0 padded, octal, null         a8  /A8
      #      char devminor[8];   // 0 padded, octal, null         a8  /A8
      #      char prefix[155];   // ASCII (+ Z unless filled)     a155/Z155
      #   };
      #
      # The #typeflag is one of several known values. POSIX indicates that "A
      # POSIX-compliant implementation must treat any unrecognized typeflag
      # value as a regular file."
      class PosixHeader
        # Fields that must be set in a POSIX tar(1) header.
        REQUIRED_FIELDS = [ :name, :size, :prefix, :mode ].freeze
        # Fields that may be set in a POSIX tar(1) header.
        OPTIONAL_FIELDS = [
          :uid, :gid, :mtime, :checksum, :typeflag, :linkname, :magic, :version,
          :uname, :gname, :devmajor, :devminor
        ].freeze

        # All fields available in a POSIX tar(1) header.
        FIELDS = (REQUIRED_FIELDS + OPTIONAL_FIELDS).freeze

        ##
        # :attr_reader: name
        # The name of the file. Limited to 100 bytes. Required.

        ##
        # :attr_reader: size
        # The size of the file. Required.

        ##
        # :attr_reader: prefix
        # The prefix of the file; the path before #name. Limited to 155 bytes.
        # Required.

        ##
        # :attr_reader: mode
        # The Unix file mode of the file. Stored as an octal integer. Required.

        ##
        # :attr_reader: uid
        # The Unix owner user ID of the file. Stored as an octal integer.

        ##
        # :attr_reader: uname
        # The user name of the Unix owner of the file.

        ##
        # :attr_reader: gid
        # The Unix owner group ID of the file. Stored as an octal integer.

        ##
        # :attr_reader: gname
        # The group name of the Unix owner of the file.

        ##
        # :attr_reader: mtime
        # The modification time of the file in epoch seconds. Stored as an
        # octal integer.

        ##
        # :attr_reader: checksum
        # The checksum of the file. Stored as an octal integer. Calculated
        # before encoding the header as a string.

        ##
        # :attr_reader: typeflag
        # The type of record in the file.
        #
        # <tt>0</tt>::  Regular file. NULL should be treated as a synonym, for
        #               compatibility purposes.
        # <tt>1</tt>::  Hard link.
        # <tt>2</tt>::  Symbolic link.
        # <tt>3</tt>::  Character device node.
        # <tt>4</tt>::  Block device node.
        # <tt>5</tt>::  Directory.
        # <tt>6</tt>::  FIFO node.
        # <tt>7</tt>::  Reserved.

        ##
        # :attr_reader: linkname
        # The name of the link stored. Not currently used.

        ##
        # :attr_reader: magic
        # Always "ustar\0".

        ##
        # :attr_reader: version
        # Always "00"

        ##
        # :attr_reader: devmajor
        # The major device ID. Not currently used.

        ##
        # :attr_reader: devminor
        # The minor device ID. Not currently used.

        FIELDS.each { |f| attr_reader f.to_sym }

        # The pack format passed to Array#pack for encoding a header.
        HEADER_PACK_FORMAT    = "a100a8a8a8a12a12a7aaa100a6a2a32a32a8a8a155"
        # The unpack format passed to String#unpack for decoding a header.
        HEADER_UNPACK_FORMAT  = "Z100A8A8A8A12A12A8aZ100A6A2Z32Z32A8A8Z155"

        class << self
          # Creates a new PosixHeader from a data stream.
          def from_stream(stream)
            from_data(stream.read(512))
          end

          # Creates a new PosixHeader from a data stream. Deprecated; use
          # PosixHeader.from_stream instead.
          def new_from_stream(stream)
            warn "#{__method__} has been deprecated; use from_stream instead."
            from_stream(stream)
          end

          # Creates a new PosixHeader from a 512-byte data buffer.
          def from_data(data)
            fields    = data.unpack(HEADER_UNPACK_FORMAT)
            name      = fields.shift
            mode      = fields.shift.oct
            uid       = fields.shift.oct
            gid       = fields.shift.oct
            size      = fields.shift.oct
            mtime     = fields.shift.oct
            checksum  = fields.shift.oct
            typeflag  = fields.shift
            linkname  = fields.shift
            magic     = fields.shift
            version   = fields.shift.oct
            uname     = fields.shift
            gname     = fields.shift
            devmajor  = fields.shift.oct
            devminor  = fields.shift.oct
            prefix    = fields.shift

            empty = (data == "\0" * 512)

            new(:name => name, :mode => mode, :uid => uid, :gid => gid,
                :size => size, :mtime => mtime, :checksum => checksum,
                :typeflag => typeflag, :magic => magic, :version => version,
                :uname => uname, :gname => gname, :devmajor => devmajor,
                :devminor => devminor, :prefix => prefix, :empty => empty,
                :linkname => linkname)
          end
        end

        # Creates a new PosixHeader. A PosixHeader cannot be created unless
        # +name+, +size+, +prefix+, and +mode+ are provided.
        def initialize(v)
          REQUIRED_FIELDS.each do |f|
            raise ArgumentError, "Field #{f} is required." unless v.has_key?(f)
          end

          v[:mtime]    = v[:mtime].to_i
          v[:checksum] ||= ""
          v[:typeflag] ||= "0"
          v[:magic]    ||= "ustar"
          v[:version]  ||= "00"

          FIELDS.each { |f| instance_variable_set("@#{f}", v[f]) }

          @empty = v[:empty]
        end

        # Indicates if the header was an empty header.
        def empty?
          @empty
        end

        # A string representation of the header.
        def to_s
          update_checksum
          header(@checksum)
        end
        alias_method :to_str, :to_s

        # Update the checksum field.
        def update_checksum
          hh = header(" " * 8)
          @checksum = oct(calculate_checksum(hh), 6)
        end

        private
        def oct(num, len)
          if num.nil?
            "\0" * (len + 1)
          else
            "%0#{len}o" % num
          end
        end

        def calculate_checksum(hdr)
          hdr.unpack("C*").inject { |aa, bb| aa + bb }
        end

        def header(chksum)
          arr = [name, oct(mode, 7), oct(uid, 7), oct(gid, 7), oct(size, 11),
                 oct(mtime, 11), chksum, " ", typeflag, linkname, magic, version,
                 uname, gname, oct(devmajor, 7), oct(devminor, 7), prefix]
          str = arr.pack(HEADER_PACK_FORMAT)
          str + "\0" * ((512 - str.size) % 512)
        end
      end
    end
  end
end
