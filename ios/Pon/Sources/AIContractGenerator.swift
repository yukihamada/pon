import Foundation

// MARK: - AI Contract Generator (Local, no external API)

struct AIContractGenerator {

    enum ContractType: String, CaseIterable {
        case businessCommission = "業務委託"
        case nda = "秘密保持"
        case systemDev = "システム開発"
        case consulting = "コンサルティング"
        case sales = "売買"
        case employment = "雇用"
        case rental = "賃貸借"
        case service = "サービス利用"

        var clauseSet: ContractClauseSet {
            switch self {
            case .businessCommission: return .businessCommission
            case .nda:               return .nda
            case .systemDev:         return .systemDev
            case .consulting:        return .consulting
            case .sales:             return .sales
            case .employment:        return .employment
            case .rental:            return .rental
            case .service:           return .service
            }
        }
    }

    struct ContractParams {
        var type: ContractType
        var partyA: String          // 甲
        var partyA_address: String
        var partyB: String          // 乙
        var partyB_address: String
        var startDate: Date
        var endDate: Date?
        var amount: Int?
        var scope: String           // 業務内容
        var deliverables: String
        var paymentTerms: String
        var specialClauses: String
    }

    static func generate(params: ContractParams) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy年M月d日"

        let startStr = dateFormatter.string(from: params.startDate)
        let endStr = params.endDate.map { dateFormatter.string(from: $0) } ?? "別途協議により定める日"
        let amountStr: String = {
            guard let amt = params.amount, amt > 0 else { return "別途協議により定める金額" }
            return "金\(amt.formatted())円（消費税別）"
        }()

        let clauses = params.type.clauseSet.buildClauses(
            params.partyA,
            params.partyB,
            params.scope,
            params.deliverables,
            amountStr,
            params.paymentTerms,
            startStr,
            endStr
        )

        var sections: [String] = []

        // Header
        sections.append("""
        \(params.type.rawValue)契約書

        \(params.partyA)（以下「甲」という。）と\(params.partyB)（以下「乙」という。）は、以下のとおり\(params.type.rawValue)契約（以下「本契約」という。）を締結する。
        """)

        // Articles
        sections.append(contentsOf: clauses)

        // Special clauses
        if !params.specialClauses.isEmpty {
            let articleNum = clauses.count + 1
            sections.append("""
            第\(articleNum)条（特約事項）
            　本契約に関し、甲乙間で以下の特約事項を定める。
            　\(params.specialClauses)
            """)
        }

        // Closing
        let closingArticle = clauses.count + (params.specialClauses.isEmpty ? 1 : 2)
        sections.append("""
        第\(closingArticle)条（協議解決）
        　本契約に定めのない事項又は本契約の解釈に疑義が生じた場合は、甲乙誠実に協議の上解決するものとする。
        """)

        sections.append("""
        以上、本契約の成立を証するため、本書2通を作成し、甲乙各1通を保有する。

        \(startStr)

        甲：\(params.partyA_address.isEmpty ? "" : "\(params.partyA_address)\n　　")\(params.partyA)
        　　（署名）________________________

        乙：\(params.partyB_address.isEmpty ? "" : "\(params.partyB_address)\n　　")\(params.partyB)
        　　（署名）________________________
        """)

        return sections.joined(separator: "\n\n")
    }
}

// MARK: - Clause Sets

struct ContractClauseSet {

    typealias ClauseBuilder = (
        _ partyA: String,
        _ partyB: String,
        _ scope: String,
        _ deliverables: String,
        _ amount: String,
        _ paymentTerms: String,
        _ startDate: String,
        _ endDate: String
    ) -> [String]

    let buildClauses: ClauseBuilder

    static let businessCommission = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（業務内容）
            　甲は乙に対し、以下の業務（以下「本業務」という。）を委託し、乙はこれを受託する。
            　（1）業務内容：\(scope.isEmpty ? "甲乙協議の上別途定める業務" : scope)
            　（2）成果物：\(deliverables.isEmpty ? "甲乙協議の上別途定める成果物" : deliverables)
            """,
            """
            第2条（委託期間）
            　本業務の委託期間は、\(start)から\(end)までとする。ただし、期間満了の1ヶ月前までに甲乙いずれかから書面による解除の申し出がない場合は、同一条件で自動更新するものとする。
            """,
            """
            第3条（委託料）
            　甲は乙に対し、本業務の対価として\(amount)を支払う。
            """,
            """
            第4条（支払方法）
            　甲は前条に定める委託料を、\(paymentTerms.isEmpty ? "毎月末日締め、翌月末日払いにて乙の指定する銀行口座へ振込送金する方法により支払う" : paymentTerms)。振込手数料は甲の負担とする。
            """,
            """
            第5条（著作権・知的財産権）
            　本業務の遂行により乙が作成した成果物に関する著作権その他の知的財産権は、乙が乙に対する委託料を完済したとき、甲に帰属するものとする。ただし、乙が本業務遂行前から保有していた知的財産権はこの限りでない。
            """,
            """
            第6条（秘密保持）
            　甲及び乙は、本契約の履行過程において相手方から開示された業務上・技術上・経営上その他一切の情報を秘密として保持し、相手方の書面による事前承諾なくして第三者に開示・漏洩してはならない。本条の義務は、本契約終了後2年間存続する。
            """,
            """
            第7条（再委託の禁止）
            　乙は、甲の書面による事前の承諾なく、本業務の全部又は一部を第三者に再委託してはならない。
            """,
            """
            第8条（契約解除）
            　甲又は乙は、相手方が次の各号のいずれかに該当した場合、催告なく本契約を解除することができる。
            　（1）本契約の条項に違反し、相当期間を定めた催告後も是正されないとき
            　（2）破産、民事再生、会社更生等の申立てがなされたとき
            　（3）差押え、仮差押え、仮処分等の強制執行を受けたとき
            """,
            """
            第9条（損害賠償）
            　甲又は乙が本契約に違反し、相手方に損害を与えた場合、当該違反当事者は相手方に対し実際に生じた損害を賠償する。ただし、賠償額は本契約に基づき甲が乙に支払った委託料の総額を上限とする。
            """,
            """
            第10条（準拠法・合意管轄）
            　本契約の準拠法は日本法とし、本契約に関して生じた紛争については、東京地方裁判所を第一審の専属的合意管轄裁判所とする。
            """
        ]
    }

    static let nda = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（目的）
            　甲及び乙は、\(scope.isEmpty ? "相互の事業に関する協議・検討" : scope)を目的として情報の開示・交換を行うにあたり、相互の秘密情報を保護するために本契約を締結する。
            """,
            """
            第2条（秘密情報の定義）
            　本契約において「秘密情報」とは、開示当事者が秘密である旨を明示して相手方に開示した技術上、経営上、財務上、その他一切の情報をいう。ただし、次の各号に該当する情報はこの限りでない。
            　（1）開示を受けた時点で既に公知であった情報
            　（2）開示を受けた後に受領当事者の責によらず公知となった情報
            　（3）開示を受けた時点で受領当事者が既に保有していた情報
            　（4）正当な権限を有する第三者から秘密保持義務なく取得した情報
            """,
            """
            第3条（秘密保持義務）
            　甲及び乙は、相手方の秘密情報を厳に秘密として保持し、相手方の書面による事前承諾なく、第三者に開示・漏洩せず、かつ本契約の目的以外に使用しない。
            """,
            """
            第4条（目的外使用の禁止）
            　甲及び乙は、相手方の秘密情報を本契約の目的の範囲内においてのみ使用し、その目的以外に利用してはならない。
            """,
            """
            第5条（複製の制限）
            　甲及び乙は、相手方の事前の書面による承諾がない限り、相手方の秘密情報を複製してはならない。
            """,
            """
            第6条（情報の管理）
            　甲及び乙は、秘密情報を善良な管理者の注意をもって管理し、秘密情報へのアクセスを業務上必要な範囲の役職員に限定する。
            """,
            """
            第7条（有効期間）
            　本契約の有効期間は、\(start)から\(end)までとする。ただし、秘密保持義務は本契約終了後も2年間存続する。
            """,
            """
            第8条（秘密情報の返還）
            　甲又は乙は、相手方から要求された場合、又は本契約が終了した場合には、相手方から提供された秘密情報（複製物を含む）を速やかに返還又は廃棄し、その旨を相手方に書面で通知する。
            """,
            """
            第9条（損害賠償）
            　甲又は乙が本契約に違反し、相手方に損害を与えた場合、当該違反当事者は相手方に生じた一切の損害を賠償する。
            """,
            """
            第10条（準拠法・合意管轄）
            　本契約の準拠法は日本法とし、本契約に関して生じた紛争については、東京地方裁判所を第一審の専属的合意管轄裁判所とする。
            """
        ]
    }

    static let systemDev = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（開発業務）
            　甲は乙に対し、以下のシステム開発業務（以下「本開発」という。）を委託し、乙はこれを受託する。
            　（1）開発内容：\(scope.isEmpty ? "甲乙協議の上別途定めるシステム" : scope)
            　（2）納入物：\(deliverables.isEmpty ? "ソースコード、設計書、操作マニュアル等甲乙協議の上別途定める成果物" : deliverables)
            """,
            """
            第2条（開発期間）
            　本開発の期間は、\(start)から\(end)までとする。
            """,
            """
            第3条（開発費用）
            　甲は乙に対し、本開発の対価として\(amount)を支払う。
            """,
            """
            第4条（支払方法）
            　甲は前条の開発費用を、\(paymentTerms.isEmpty ? "着手金50%を契約締結時、残金50%を納品検収完了時に、乙の指定する銀行口座への振込により支払う" : paymentTerms)。
            """,
            """
            第5条（納品・検収）
            　乙は第2条に定める期間内に成果物を甲に納品する。甲は納品を受けた日から14日以内に検収を行い、合否を書面で乙に通知する。甲が当該期間内に通知しない場合は検収合格とみなす。
            """,
            """
            第6条（瑕疵担保）
            　乙は検収合格後3ヶ月以内に発見された本開発の瑕疵について、無償で修補する義務を負う。ただし、甲の責に帰すべき事由による瑕疵はこの限りでない。
            """,
            """
            第7条（著作権）
            　本開発により作成された成果物の著作権は、乙が対価の全額を受領したとき甲に帰属する。ただし、乙が本開発以前から保有するコンポーネント・ライブラリ等についてはこの限りでない。
            """,
            """
            第8条（秘密保持）
            　甲及び乙は、本契約の履行過程で知り得た相手方の技術情報・事業情報を秘密として保持し、第三者に開示・漏洩しない。本義務は本契約終了後2年間存続する。
            """,
            """
            第9条（契約解除・損害賠償）
            　甲又は乙が本契約に違反した場合、相手方は14日間の催告期間を設けて本契約を解除できる。違反当事者は相手方の損害を賠償する。ただし賠償上限は開発費用の総額とする。
            """,
            """
            第10条（準拠法・合意管轄）
            　本契約の準拠法は日本法とし、紛争については東京地方裁判所を第一審の専属的合意管轄裁判所とする。
            """
        ]
    }

    static let consulting = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（コンサルティング業務）
            　甲は乙に対し、\(scope.isEmpty ? "経営・事業に関するコンサルティング業務" : scope)（以下「本業務」という。）を委託し、乙はこれを受託する。
            """,
            """
            第2条（契約期間）
            　本契約の有効期間は\(start)から\(end)までとする。
            """,
            """
            第3条（報酬）
            　甲は乙に対し、本業務の対価として\(amount)を支払う。
            """,
            """
            第4条（支払方法）
            　\(paymentTerms.isEmpty ? "甲は毎月末日締め、翌月末日払いにて乙指定の口座に振込む" : paymentTerms)。
            """,
            """
            第5条（善管注意義務）
            　乙は善良な管理者の注意をもって本業務を遂行する。ただし、本業務の成果について特定の結果を保証するものではない。
            """,
            """
            第6条（秘密保持・競業避止）
            　乙は本業務遂行上知り得た甲の秘密情報を本契約終了後2年間第三者に開示せず、甲の競合事業への提供も行わない。
            """,
            """
            第7条（知的財産権）
            　本業務で乙が提供した資料・レポート等の著作権は乙に帰属するが、甲は自社内部利用に限り利用できる。
            """,
            """
            第8条（契約解除）
            　甲乙は1ヶ月前の書面通知により本契約を解除できる。違反解除の場合は損害賠償義務を負う。
            """,
            """
            第9条（免責）
            　乙のアドバイスに基づき甲が行った経営判断の結果について、乙は責任を負わない。ただし乙の故意・重過失の場合はこの限りでない。
            """,
            """
            第10条（準拠法・合意管轄）
            　本契約の準拠法は日本法とし、紛争については東京地方裁判所を専属的合意管轄裁判所とする。
            """
        ]
    }

    static let sales = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（売買）
            　甲は乙に対し、以下の物品（以下「本件商品」という。）を売り渡し、乙はこれを買い受ける。
            　商品：\(scope.isEmpty ? "甲乙別途協議の上定める商品" : scope)
            　数量・仕様：\(deliverables.isEmpty ? "別途注文書に定めるとおり" : deliverables)
            """,
            """
            第2条（代金）
            　乙は甲に対し、本件商品の代金として\(amount)を支払う。
            """,
            """
            第3条（支払方法）
            　\(paymentTerms.isEmpty ? "乙は代金を納品日から30日以内に甲指定口座に振込む" : paymentTerms)。
            """,
            """
            第4条（引渡し）
            　甲は\(start)までに本件商品を乙の指定する場所に引き渡す。引渡完了時に商品の所有権は甲から乙へ移転する。
            """,
            """
            第5条（危険負担）
            　本件商品の引渡し完了後の滅失・毀損等のリスクは乙が負担する。
            """,
            """
            第6条（瑕疵担保）
            　甲は引渡日から3ヶ月以内に発見された本件商品の瑕疵について補修又は交換の義務を負う。ただし通常の使用による損耗・天災等はこの限りでない。
            """,
            """
            第7条（所有権留保）
            　甲は乙が代金を完済するまで本件商品の所有権を留保する。乙が支払を怠った場合、甲は本件商品の返還を請求できる。
            """,
            """
            第8条（反社会的勢力の排除）
            　甲及び乙は、自己及び役員が反社会的勢力でないことを表明・保証する。違反が判明した場合は催告なく本契約を解除できる。
            """,
            """
            第9条（損害賠償）
            　本契約違反により相手方に損害を与えた場合、違反当事者は実損額を賠償する。ただし上限は本件商品の代金総額とする。
            """,
            """
            第10条（準拠法・合意管轄）
            　本契約の準拠法は日本法とし、紛争については東京地方裁判所を専属的合意管轄裁判所とする。
            """
        ]
    }

    static let employment = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（雇用）
            　甲（使用者）は乙（労働者）を以下の条件で雇用し、乙はこれを承諾する。
            　職種：\(scope.isEmpty ? "甲の指定する業務全般" : scope)
            """,
            """
            第2条（雇用期間）
            　雇用期間は\(start)から\(end)までとする。ただし、期間満了1ヶ月前までに当事者より解除の意思表示がない場合は自動更新する。
            """,
            """
            第3条（賃金）
            　甲は乙に対し、\(amount)を支払う。
            """,
            """
            第4条（支払方法）
            　\(paymentTerms.isEmpty ? "甲は毎月末日締め翌月25日払いで乙指定口座に振込む" : paymentTerms)。
            """,
            """
            第5条（勤務時間・場所）
            　勤務時間・場所は甲の就業規則に従う。
            """,
            """
            第6条（服務規律）
            　乙は甲の就業規則・指示命令に従い誠実に職務に従事する。
            """,
            """
            第7条（秘密保持・競業避止）
            　乙は在職中及び退職後2年間、甲の秘密情報を漏洩せず、競合行為を行わない。
            """,
            """
            第8条（知的財産）
            　乙が職務上作成した著作物・発明等の知的財産権は甲に帰属する。
            """,
            """
            第9条（解雇・退職）
            　甲は労働基準法に従い解雇予告又は解雇予告手当を支払うことで解雇できる。乙は30日前に書面で申し出ることで退職できる。
            """,
            """
            第10条（準拠法）
            　本契約は日本法に準拠し、紛争については管轄裁判所において解決する。
            """
        ]
    }

    static let rental = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（賃貸借）
            　甲（賃貸人）は乙（賃借人）に対し、以下の物件を賃貸し、乙はこれを賃借する。
            　物件：\(scope.isEmpty ? "別途合意した物件" : scope)
            """,
            """
            第2条（賃借期間）
            　賃借期間は\(start)から\(end)までとする。
            """,
            """
            第3条（賃料）
            　乙は甲に対し、賃料として\(amount)を支払う。
            """,
            """
            第4条（支払方法）
            　\(paymentTerms.isEmpty ? "乙は毎月末日までに翌月分賃料を甲指定口座に振込む" : paymentTerms)。
            """,
            """
            第5条（使用目的）
            　乙は本物件を\(deliverables.isEmpty ? "甲が承認した目的" : deliverables)にのみ使用し、目的外使用・転貸は甲の書面承諾を要する。
            """,
            """
            第6条（善管注意義務）
            　乙は本物件を善良な管理者の注意をもって使用・保管する。
            """,
            """
            第7条（修繕）
            　通常使用による損耗の修繕は甲が行う。乙の故意・過失による損傷は乙が費用負担する。
            """,
            """
            第8条（原状回復）
            　乙は契約終了時に本物件を原状に回復して甲に返還する。
            """,
            """
            第9条（契約解除）
            　賃料の3ヶ月以上の滞納その他重大な契約違反がある場合、甲は催告の上本契約を解除できる。
            """,
            """
            第10条（準拠法・合意管轄）
            　本契約の準拠法は日本法とし、紛争については物件所在地を管轄する裁判所を専属的合意管轄裁判所とする。
            """
        ]
    }

    static let service = ContractClauseSet { a, b, scope, deliverables, amount, paymentTerms, start, end in
        [
            """
            第1条（サービス内容）
            　甲は乙に対し、\(scope.isEmpty ? "別途定めるサービス" : scope)（以下「本サービス」という。）を提供し、乙はこれを利用する。
            """,
            """
            第2条（利用期間）
            　本サービスの利用期間は\(start)から\(end)までとする。
            """,
            """
            第3条（利用料金）
            　乙は甲に対し、本サービスの対価として\(amount)を支払う。
            """,
            """
            第4条（支払方法）
            　\(paymentTerms.isEmpty ? "乙は毎月末日までに当月分利用料を甲指定口座に振込む" : paymentTerms)。
            """,
            """
            第5条（利用条件）
            　乙は本サービスを本契約の目的の範囲内において利用し、甲の定める利用規約を遵守する。
            """,
            """
            第6条（禁止事項）
            　乙は本サービスを利用して、法令違反行為・甲又は第三者の権利侵害行為・公序良俗に反する行為を行ってはならない。
            """,
            """
            第7条（サービスの停止）
            　甲はシステムメンテナンス・不可抗力等の事由により、予告の上本サービスを一時停止できる。緊急時は予告なく停止できる。
            """,
            """
            第8条（知的財産権）
            　本サービスに関する知的財産権は甲に帰属する。乙は本サービスの範囲内でのみ利用権を有する。
            """,
            """
            第9条（免責・損害賠償上限）
            　甲は本サービスの不具合・停止による乙の損害について、甲の故意・重過失の場合を除き責任を負わない。賠償上限は乙が支払った過去3ヶ月の利用料とする。
            """,
            """
            第10条（準拠法・合意管轄）
            　本契約の準拠法は日本法とし、紛争については東京地方裁判所を専属的合意管轄裁判所とする。
            """
        ]
    }
}
