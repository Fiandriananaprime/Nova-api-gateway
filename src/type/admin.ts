export type { SellerApplication,PaginationMeta } from "@Fiandriananaprime/nova_api_type"


export type GetApplicationQuery = {
    page: number,
    limit: number,
    status?: "pending" | "approved" | "rejected"
}

export type createVerificationDocument = {
    type : "identity" | "business_registration" | "tax_document" | "bank_account",
    fileUrl: string,
}

export type store = {
    location: string,
    storeName: string,
    businessType: "individual" | "company",
    taxId?: string,
    registrationNumber?: string,
    documents:createVerificationDocument[]
}

export type createSellerApplication = {
    userId:string,
    comments:string,
    store: store
}

export type createApplication = { comments: string,store:store}