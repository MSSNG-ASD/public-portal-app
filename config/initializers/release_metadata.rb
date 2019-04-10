module ReleaseMetadata
    RELEASE = nil  # `cat .deployed-release`.chomp
    REVISION = nil  # `cat .deployed-commit`.chomp
    VERSION = nil  # `cat .deployed-version`.chomp
end
