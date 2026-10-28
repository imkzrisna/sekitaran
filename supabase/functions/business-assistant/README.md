# Business assistant legacy endpoint

Current Flutter clients call `recommend-stores`. Older app builds may still
call the deployed `business-assistant` endpoint, so keep its retrieval behavior
compatible. Both endpoints retrieve the complete bounded comment set through
`get_all_business_comments_for_assistant` for general questions; they do not
filter evidence by lexical overlap with the question.

Deploy both endpoints when changing the shared assistant retrieval contract.
Store-specific questions from current clients use the store-scoped RPC in the
`recommend-stores` function.
