# Orders the extra approvers (after L1 → L2) for a tour plan or a claim.
#   needs: [[reason, [[user_id, position], …]], …] – one entry per travel mode / visit that needs extra approval
# A person's highest position wins (COO 1 → Director 2), people already in the chain (employee, L1, L2) are
# skipped, and each approver keeps the reasons (e.g. "Flight, Personal Four Wheeler").
class ExtraApprovalChain
  def self.build(needs, skip:)
    rank = {}
    reasons = Hash.new { |h, k| h[k] = [] }
    needs.each do |reason, chain|
      chain.each do |uid, pos|
        rank[uid] = [ rank[uid].to_i, pos ].max
        reasons[uid] << reason
      end
    end
    skip = Array(skip).compact
    rank.keys.reject { |id| skip.include?(id) }
        .each_with_index.sort_by { |id, i| [ rank[id], i ] }.map(&:first)
        .map { |uid| [ uid, reasons[uid].uniq.join(", ").first(200) ] }
  end
end
