import { z } from 'zod';

// Address schema
export const AddressSchema = z.object({
  city: z.string().optional(),
  district: z.string().optional(),
  region: z.string().optional(),
  state: z.string().optional(),
  locality: z.object({
    code: z.string(),
    name: z.string().optional(),
  }).optional(),
  pincode: z.string().optional(),
  landmark: z.string().optional(),
  geoLocation: z.object({
    latitude: z.number().optional(),
    longitude: z.number().optional(),
  }).optional(),
});

// PGR Service (complaint)
export const ServiceSchema = z.object({
  tenantId: z.string(),
  serviceCode: z.string(),
  serviceRequestId: z.string().optional(),
  description: z.string().optional(),
  accountId: z.string().optional(),
  applicationStatus: z.string().optional(),
  source: z.string().optional(),
  address: AddressSchema.optional(),
  auditDetails: z.object({
    createdBy: z.string().optional(),
    lastModifiedBy: z.string().optional(),
    createdTime: z.number().optional(),
    lastModifiedTime: z.number().optional(),
  }).optional(),
});

// Service Wrapper (includes workflow)
export const ServiceWrapperSchema = z.object({
  service: ServiceSchema,
  workflow: z.object({
    action: z.string().optional(),
    assignes: z.array(z.string()).optional(),
    comments: z.string().optional(),
  }).optional(),
});

// Search request
export const SearchServiceRequestSchema = z.object({
  RequestInfo: z.object({
    apiId: z.string(),
    ver: z.string().optional(),
    action: z.string().optional(),
    msgId: z.string().optional(),
    authToken: z.string().optional(),
    userInfo: z.object({
      uuid: z.string(),
      type: z.string(),
      tenantId: z.string(),
    }).optional(),
  }),
});

// Search response
export const SearchServiceResponseSchema = z.object({
  ResponseInfo: z.object({
    apiId: z.string().nullable().optional(),
    ver: z.string().nullable().optional(),
    ts: z.number().nullable().optional(),
    resMsgId: z.string().nullable().optional(),
    msgId: z.string().nullable().optional(),
    status: z.string().nullable().optional(),
  }).nullable().optional(),
  ServiceWrappers: z.array(ServiceWrapperSchema),
});

// Create request
export const CreateServiceRequestSchema = z.object({
  RequestInfo: z.object({
    apiId: z.string(),
    ver: z.string().optional(),
    action: z.string().optional(),
    msgId: z.string().optional(),
    authToken: z.string().optional(),
    userInfo: z.object({
      uuid: z.string(),
      type: z.string(),
      tenantId: z.string(),
    }),
  }),
  service: z.object({
    tenantId: z.string(),
    serviceCode: z.string(),
    description: z.string().optional(),
    source: z.string().optional(),
    address: AddressSchema.optional(),
  }),
});

export type Address = z.infer<typeof AddressSchema>;
export type Service = z.infer<typeof ServiceSchema>;
export type ServiceWrapper = z.infer<typeof ServiceWrapperSchema>;
export type SearchServiceResponse = z.infer<typeof SearchServiceResponseSchema>;
