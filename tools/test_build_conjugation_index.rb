# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"
require_relative "build_conjugation_index"

class TestConjugationIndex < Minitest::Test
  class Generator
    def initialize(headword)
      @headword = headword
    end

    def conjugate!
      { verb: @headword, first: { basic: [["LIKĒS", "kakes (of 2)", "likēt os", "N/A"]] } }
    end
  end

  class FailingGenerator
    def initialize(_headword); end

    def conjugate!
      raise "unsupported"
    end
  end

  def setup
    @builder = ConjugationIndex.new(
      action_paradigms: [{ key: "action.present", mod: Generator }],
      stative_paradigms: [],
      blocked_stems: ["ometv"],
      normalizer: ->(word) { word.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.strip }
    )
  end

  def build(rows)
    Tempfile.create("lexicon") do |file|
      rows.each { |row| file.puts(JSON.generate(row)) }
      file.flush
      @builder.build(file.path)
    end
  end

  def test_indexes_all_senses_and_lookups_without_annotation
    index = build([
      { sense_id: "one", headword: "liketv" },
      { sense_id: "two", headword: "liketv" },
      { sense_id: "three", headword: "likēs" }
    ])
    assert_equal %w[one three two], index["likēs"]
    assert_equal %w[one three two], index["likes"]
    assert_equal %w[one two], index["kakes"]
    assert_equal %w[one two], index["likēt"]
    assert_equal %w[one two], index["liket os"]
    refute index.key?("n/a")
    refute index.key?("kakes (of 2)")
  end

  def test_rejects_duplicate_or_missing_sense_ids
    assert_raises(ArgumentError) { build([{ headword: "liketv" }]) }
    assert_raises(ArgumentError) do
      build([{ sense_id: "one", headword: "liketv" }, { sense_id: "one", headword: "liketv" }])
    end
  end

  def test_reports_failed_paradigms_but_retains_headwords_and_successful_forms
    @builder = ConjugationIndex.new(
      action_paradigms: [
        { key: "failed", mod: FailingGenerator },
        { key: "present", mod: Generator }
      ],
      stative_paradigms: [],
      blocked_stems: [],
      normalizer: ->(word) { word.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.strip }
    )
    index = nil
    _, stderr = capture_io { index = build([{ sense_id: "one", headword: "liketv" }]) }
    assert_includes stderr, "liketv (failed): RuntimeError: unsupported"
    assert_equal ["one"], index["liketv"]
    assert_equal ["one"], index["likes"]
  end
end
