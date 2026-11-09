import Testing
@testable import News_Digest

struct HTMLTextTests {
    @Test func stripsTagsAndCollapsesWhitespace() {
        #expect("<p>One</p>\n\n<p>Two   <em>three</em></p>".strippingHTML == "One Two three")
    }

    @Test func removesScriptAndStyleBlocks() {
        let html = "Before<script>alert('x')</script><style>p{color:red}</style>After"
        #expect(html.strippingHTML == "Before After")
    }

    @Test func decodesNamedAndNumericEntities() {
        #expect("Tom &amp; Jerry &#8217;s &#x2014; &lt;ok&gt;".decodingHTMLEntities == "Tom & Jerry ’s — <ok>")
    }

    @Test func doesNotDoubleDecode() {
        #expect("&amp;lt;".decodingHTMLEntities == "&lt;")
    }

    @Test func plainTextPassesThrough() {
        #expect("Nothing to strip".strippingHTML == "Nothing to strip")
    }
}
